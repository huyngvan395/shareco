import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'verified', 'banned', 'can_live_false', 'strikes'

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminBloc()..add(AdminFetchUsers()),
      child: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state.status == AdminStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AdminPalette.danger,
              ),
            );
          }
        },
        builder: (context, state) {
          final allUsers = state.users;
          final verifiedCount = allUsers.where((u) => u['is_verified'] == true).length;
          final bannedCount = allUsers.where((u) => u['is_banned'] == true).length;
          final liveRestrictedCount = allUsers.where((u) => u['can_live'] == false && u['is_banned'] != true).length;
          final strikesCount = allUsers.where((u) => ((u['strike_count'] as num?)?.toInt() ?? 0) > 0).length;

          final filteredUsers = allUsers.where((u) {
            final name = (u['display_name'] ?? '').toString().toLowerCase();
            final username = (u['username'] ?? '').toString().toLowerCase();
            final bio = (u['bio'] ?? '').toString().toLowerCase();
            final q = _searchQuery.trim().toLowerCase();
            final matches = q.isEmpty || name.contains(q) || username.contains(q) || bio.contains(q);
            if (!matches) return false;

            final isVerified = u['is_verified'] == true;
            final isBanned = u['is_banned'] == true;
            final canLive = u['can_live'] ?? true;
            final strikes = (u['strike_count'] as num?)?.toInt() ?? 0;

            if (_filterType == 'verified') return isVerified;
            if (_filterType == 'banned') return isBanned;
            if (_filterType == 'can_live_false') return !canLive && !isBanned;
            if (_filterType == 'strikes') return strikes > 0;
            return true;
          }).toList();

          return AdminLayout(
            title: 'Quản Lý Người Dùng, Creator & Kiểm Duyệt Vi Phạm',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Header
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Tổng Người Dùng',
                        value: '${allUsers.length}',
                        subtitle: 'Tài khoản hoạt động trên nền tảng',
                        icon: Icons.people_alt_rounded,
                        color: AdminPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Creator Tích Xanh',
                        value: '$verifiedCount',
                        subtitle: 'Nhà sáng tạo nội dung đã xác thực',
                        icon: Icons.verified_rounded,
                        color: AdminPalette.info,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Tài Khoản Bị Khóa',
                        value: '$bannedCount',
                        subtitle: 'Vi phạm chính sách cộng đồng (Ban)',
                        icon: Icons.person_off_rounded,
                        color: AdminPalette.danger,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Cấm Live / Cảnh Cáo',
                        value: '${liveRestrictedCount + strikesCount}',
                        subtitle: 'Bị giới hạn livestream hoặc dính gậy',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search & Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Tìm theo tên hiển thị, @username hoặc bio...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AdminPalette.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AdminPalette.textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AdminPalette.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Filter chips
                      _buildFilterPill('Tất cả (${allUsers.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Tích xanh ($verifiedCount)', 'verified'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Bị cấm Live ($liveRestrictedCount)', 'can_live_false'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Dính gậy ($strikesCount)', 'strikes'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Đã khóa ($bannedCount)', 'banned'),
                      const SizedBox(width: 12),

                      // Refresh button
                      Tooltip(
                        message: 'Tải lại danh sách người dùng',
                        child: InkWell(
                          onTap: () => context.read<AdminBloc>().add(AdminFetchUsers()),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdminPalette.border),
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: AdminPalette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Table Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: state.status == AdminStatus.loading && allUsers.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredUsers.isEmpty
                            ? _buildEmptyState(context)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SingleChildScrollView(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFF8FAFC),
                                      ),
                                      headingRowHeight: 50,
                                      dataRowMinHeight: 74,
                                      dataRowMaxHeight: 88,
                                      horizontalMargin: 20,
                                      columnSpacing: 18,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'NGƯỜI DÙNG / CREATOR',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'TIỂU SỬ & LIÊN HỆ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'TRẠNG THÁI & HUY HIỆU',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'VI PHẠM / GẬY CẢNH CÁO',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'HÀNH ĐỘNG KIỂM DUYỆT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredUsers.map((user) {
                                        final isVerified = user['is_verified'] == true;
                                        final isBanned = user['is_banned'] == true;
                                        final canLive = user['can_live'] ?? true;
                                        final canComment = user['can_comment'] ?? true;
                                        final strikeCount = (user['strike_count'] as num?)?.toInt() ?? 0;
                                        final avatarUrl = user['avatar_url'];
                                        final username = user['username'] ?? 'user';
                                        final rawDisplayName = (user['display_name'] ?? '').toString().trim();
                                        final displayName = rawDisplayName.isNotEmpty ? rawDisplayName : '@$username';
                                        final bio = (user['bio'] ?? '').toString().trim();
                                        final phone = (user['phone_number'] ?? user['phone'] ?? '').toString().trim();
                                        final banReason = (user['ban_reason'] ?? '').toString().trim();
                                        final videoCount = (user['video_count'] as num?)?.toInt() ?? 0;
                                        final followerCount = (user['follower_count'] as num?)?.toInt() ?? 0;
                                        final coinBalance = (user['coin_balance'] as num?)?.toInt() ?? 0;
                                        final userId = (user['id'] ?? '').toString();
                                        final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

                                        return DataRow(
                                          cells: [
                                            // Col 1: User info
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 22,
                                                    backgroundColor: const Color(0xFFE2E8F0),
                                                    backgroundImage: (avatarUrl != null && avatarUrl.toString().trim().isNotEmpty)
                                                        ? NetworkImage(avatarUrl)
                                                        : null,
                                                    child: (avatarUrl == null || avatarUrl.toString().trim().isEmpty)
                                                        ? const Icon(Icons.person_rounded, size: 24, color: AdminPalette.textSecondary)
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            displayName,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 13.5,
                                                              color: AdminPalette.textPrimary,
                                                            ),
                                                          ),
                                                          if (isVerified) ...[
                                                            const SizedBox(width: 4),
                                                            const Tooltip(
                                                              message: 'Tài khoản Creator Tích Xanh',
                                                              child: Icon(
                                                                Icons.verified_rounded,
                                                                color: AdminPalette.info,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '@$username  •  ID: $shortId...',
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          color: AdminPalette.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Col 2: Bio & Thống kê
                                            DataCell(
                                              SizedBox(
                                                width: 250,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (bio.isNotEmpty)
                                                      Text(
                                                        bio,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AdminPalette.textPrimary,
                                                        ),
                                                      )
                                                    else
                                                      const Text(
                                                        'Chưa có tiểu sử',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: AdminPalette.textSecondary,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '🎬 $videoCount video',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AdminPalette.primary,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '👥 $followerCount follows',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF0284C7),
                                                            ),
                                                          ),
                                                        ),
                                                        if (coinBalance > 0) ...[
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '🪙 $coinBalance',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                              color: Color(0xFFD97706),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    if (phone.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '📞 $phone',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AdminPalette.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Col 3: Status Badges
                                            DataCell(
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  if (isBanned)
                                                    const AdminStatusBadge(
                                                      label: 'Đã Khóa (Banned) ⛔',
                                                      color: AdminPalette.danger,
                                                    )
                                                  else
                                                    const AdminStatusBadge(
                                                      label: 'Bình thường ✅',
                                                      color: AdminPalette.success,
                                                    ),
                                                  if (!canLive && !isBanned)
                                                    const AdminStatusBadge(
                                                      label: 'Cấm Live 🚫📹',
                                                      color: Color(0xFFF97316),
                                                    ),
                                                  if (!canComment && !isBanned)
                                                    const AdminStatusBadge(
                                                      label: 'Cấm bình luận 🔇',
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  if (isVerified)
                                                    const AdminStatusBadge(
                                                      label: 'Tích Xanh 🏅',
                                                      color: AdminPalette.info,
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Col 4: Strikes & Violation detail
                                            DataCell(
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        strikeCount == 0
                                                            ? Icons.verified_user_rounded
                                                            : Icons.warning_rounded,
                                                        size: 16,
                                                        color: strikeCount == 0
                                                            ? AdminPalette.success
                                                            : (strikeCount >= 3
                                                                ? AdminPalette.danger
                                                                : const Color(0xFFF59E0B)),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        '$strikeCount / 3 Gậy vi phạm',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 12.5,
                                                          color: strikeCount == 0
                                                              ? AdminPalette.textPrimary
                                                              : (strikeCount >= 3
                                                                  ? AdminPalette.danger
                                                                  : const Color(0xFFD97706)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (banReason.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    SizedBox(
                                                      width: 180,
                                                      child: Text(
                                                        banReason,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          color: AdminPalette.danger,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            // Col 5: Actions
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Toggle Verified
                                                  _buildActionButton(
                                                    tooltip: isVerified
                                                        ? 'Gỡ tích xanh Creator'
                                                        : 'Cấp tích xanh Creator',
                                                    icon: isVerified
                                                        ? Icons.verified_rounded
                                                        : Icons.verified_outlined,
                                                    color: isVerified
                                                        ? AdminPalette.info
                                                        : AdminPalette.textSecondary,
                                                    onTap: () {
                                                      context.read<AdminBloc>().add(
                                                            AdminToggleUserVerified(
                                                              userId: user['id'],
                                                              isVerified: !isVerified,
                                                            ),
                                                          );
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            !isVerified
                                                                ? 'Đã cấp tích xanh cho creator [@$username]!'
                                                                : 'Đã gỡ tích xanh của [@$username].',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // Toggle Can Live
                                                  _buildActionButton(
                                                    tooltip: canLive
                                                        ? 'Cấm phát Livestream'
                                                        : 'Mở lại quyền phát Livestream',
                                                    icon: canLive
                                                        ? Icons.videocam_rounded
                                                        : Icons.videocam_off_rounded,
                                                    color: canLive
                                                        ? AdminPalette.primary
                                                        : const Color(0xFFF97316),
                                                    onTap: () => _toggleCanLiveDialog(context, user),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // Issue Strike Warning
                                                  _buildActionButton(
                                                    tooltip: 'Cấp gậy cảnh cáo vi phạm tiêu chuẩn cộng đồng',
                                                    icon: Icons.flag_rounded,
                                                    color: const Color(0xFFF59E0B),
                                                    onTap: () => _showIssueWarningDialog(context, user),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // Ban / Unban account
                                                  _buildActionButton(
                                                    tooltip: isBanned
                                                        ? 'Mở khóa tài khoản'
                                                        : 'Khóa tài khoản (Ban Account)',
                                                    icon: isBanned
                                                        ? Icons.lock_open_rounded
                                                        : Icons.block_rounded,
                                                    color: isBanned
                                                        ? AdminPalette.success
                                                        : AdminPalette.danger,
                                                    onTap: () {
                                                      if (isBanned) {
                                                        _confirmUnban(context, user);
                                                      } else {
                                                        _showBanDialog(context, user);
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final selected = _filterType == value;
    return InkWell(
      onTap: () => setState(() => _filterType = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AdminPalette.primary.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AdminPalette.primary : AdminPalette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AdminPalette.primary : AdminPalette.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy người dùng phù hợp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thử thay đổi từ khóa tìm kiếm hoặc chọn bộ lọc khác.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _toggleCanLiveDialog(BuildContext context, Map<String, dynamic> user) {
    final canLive = user['can_live'] ?? true;
    final username = user['username'] ?? 'user';

    if (!canLive) {
      // Mở lại live
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Mở Lại Quyền Livestream', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text('Xác nhận khôi phục quyền phát sóng Livestream cho tài khoản [@$username]?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                context.read<AdminBloc>().add(AdminToggleUserCanLive(userId: user['id'], canLive: true));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã mở lại quyền Livestream cho [@$username]!'), backgroundColor: AdminPalette.success),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.success, foregroundColor: Colors.white),
              child: const Text('Khôi Phục Live'),
            ),
          ],
        ),
      );
      return;
    }

    // Cấm live
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded, color: Color(0xFFF97316)),
            ),
            const SizedBox(width: 12),
            const Text('Cấm Phát Livestream', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản [@$username] sẽ bị tước quyền tạo phòng phát Livestream. Nhập lý do vi phạm:',
                style: const TextStyle(fontSize: 13, height: 1.4, color: AdminPalette.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'VD: Vi phạm bản quyền âm thanh, quảng cáo phản cảm...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickReasonChip('Vi phạm bản quyền nhạc trong phiên Live', reasonController),
                  _buildQuickReasonChip('Hành vi không phù hợp thuần phong mỹ tục', reasonController),
                  _buildQuickReasonChip('Bán hàng cấm trong danh mục hạn chế', reasonController),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              context.read<AdminBloc>().add(AdminToggleUserCanLive(
                    userId: user['id'],
                    canLive: false,
                    reason: reason.isNotEmpty ? reason : 'Vi phạm quy định Livestream',
                  ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã cấm phát Livestream tài khoản [@$username]!'), backgroundColor: const Color(0xFFF97316)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
            child: const Text('Xác Nhận Cấm Live'),
          ),
        ],
      ),
    );
  }

  void _showIssueWarningDialog(BuildContext context, Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    final username = user['username'] ?? 'user';
    final currentStrikes = (user['strike_count'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 12),
            Text('Gửi Cảnh Cáo Vi Phạm (Gậy $currentStrikes/3)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cấp 01 gậy cảnh cáo vi phạm Tiêu chuẩn Cộng đồng ShareCo cho [@$username]. '
                '${currentStrikes + 1 >= 3 ? "⚠️ CẢNH BÁO: Đạt 3 gậy sẽ tự động khóa tài khoản vĩnh viễn!" : "Tài khoản tích lũy 3 gậy sẽ bị khóa."}',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: currentStrikes + 1 >= 3 ? AdminPalette.danger : AdminPalette.textSecondary,
                  fontWeight: currentStrikes + 1 >= 3 ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung vi phạm tiêu chuẩn cộng đồng...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickReasonChip('Bình luận công kích, xúc phạm cá nhân', reasonController),
                  _buildQuickReasonChip('Đăng tải video spam link độc hại', reasonController),
                  _buildQuickReasonChip('Quảng cáo sản phẩm giả mạo nhãn hiệu', reasonController),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              context.read<AdminBloc>().add(AdminIssueUserWarning(
                    userId: user['id'],
                    reason: reason,
                  ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã gửi gậy cảnh cáo cho [@$username]!'),
                  backgroundColor: currentStrikes + 1 >= 3 ? AdminPalette.danger : const Color(0xFFF59E0B),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
            child: const Text('Cấp Gậy Cảnh Cáo'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(BuildContext context, Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    final username = user['username'] ?? 'user';
    int? selectedDuration = 7; // 7 days, 30 days, null (permanent)

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminPalette.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: AdminPalette.danger),
                ),
                const SizedBox(width: 12),
                const Text('Khóa Tài Khoản (Ban Account)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài khoản [@$username] sẽ bị vô hiệu hóa đăng nhập, ẩn toàn bộ video và thu hồi quyền livestream/bình luận.',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AdminPalette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  const Text('Thời hạn khóa:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDurationChoice(
                        label: '7 Ngày',
                        value: 7,
                        current: selectedDuration,
                        onSelect: (v) => setDialogState(() => selectedDuration = v),
                      ),
                      const SizedBox(width: 8),
                      _buildDurationChoice(
                        label: '30 Ngày',
                        value: 30,
                        current: selectedDuration,
                        onSelect: (v) => setDialogState(() => selectedDuration = v),
                      ),
                      const SizedBox(width: 8),
                      _buildDurationChoice(
                        label: 'Vĩnh Viễn ⛔',
                        value: null,
                        current: selectedDuration,
                        onSelect: (v) => setDialogState(() => selectedDuration = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Lý do khóa tài khoản',
                      hintText: 'VD: Lừa đảo, spam hàng giả, vi phạm nghiêm trọng...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickReasonChip('Phát tán hàng giả nhái, lừa đảo người mua', reasonController),
                      _buildQuickReasonChip('Gian lận đơn hàng / Voucher hệ thống', reasonController),
                      _buildQuickReasonChip('Vi phạm nghiêm trọng Tiêu chuẩn Cộng đồng', reasonController),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) return;
                  context.read<AdminBloc>().add(AdminBanUser(
                        userId: user['id'],
                        isBanned: true,
                        reason: reason,
                        durationDays: selectedDuration,
                      ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã khóa tài khoản [@$username]!'), backgroundColor: AdminPalette.danger),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.danger, foregroundColor: Colors.white),
                child: const Text('Xác Nhận Khóa Tài Khoản'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmUnban(BuildContext context, Map<String, dynamic> user) {
    final username = user['username'] ?? 'user';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Mở Khóa Tài Khoản', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Bạn có chắc chắn muốn mở khóa cho tài khoản [@$username]?\nTài khoản sẽ có thể đăng nhập và hoạt động bình thường trở lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context.read<AdminBloc>().add(AdminBanUser(userId: user['id'], isBanned: false));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã mở khóa cho tài khoản [@$username]!'), backgroundColor: AdminPalette.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.success, foregroundColor: Colors.white),
            child: const Text('Mở Khóa Ngay'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChoice({
    required String label,
    required int? value,
    required int? current,
    required ValueChanged<int?> onSelect,
  }) {
    final isSelected = current == value;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AdminPalette.danger.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AdminPalette.danger : AdminPalette.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AdminPalette.danger : AdminPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReasonChip(String text, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = text,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: AdminPalette.textSecondary),
        ),
      ),
    );
  }
}

