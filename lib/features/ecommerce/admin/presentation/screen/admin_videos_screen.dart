import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';

class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'draft', 'published', 'blocked', 'tagged'

  List<Map<String, dynamic>> _extractTaggedProducts(Map<String, dynamic> video) {
    final rawTags = video['video_product_tags'];
    if (rawTags is! List) return [];
    final result = <Map<String, dynamic>>[];
    for (final t in rawTags) {
      if (t is Map && t['products'] is Map) {
        result.add(Map<String, dynamic>.from(t['products'] as Map));
      }
    }
    return result;
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '0:15';
    final totalSec = (durationMs / 1000).round();
    final min = totalSec ~/ 60;
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String? _validImageUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:')) {
      return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminBloc()..add(AdminFetchVideos()),
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
          final allVideos = state.videos;
          final pendingCount =
              allVideos.where((v) => (v['status'] ?? 'draft') == 'draft').length;
          final publishedCount =
              allVideos.where((v) => v['status'] == 'published').length;
          final blockedCount =
              allVideos.where((v) => v['status'] == 'blocked').length;

          final filteredVideos = allVideos.where((v) {
            final q = _searchQuery.trim().toLowerCase();
            final caption = (v['caption'] ?? '').toString().toLowerCase();
            final profile = v['profiles'] is Map
                ? Map<String, dynamic>.from(v['profiles'] as Map)
                : <String, dynamic>{};
            final username = (profile['username'] ?? '').toString().toLowerCase();
            final displayName =
                (profile['display_name'] ?? '').toString().toLowerCase();
            final tagged = _extractTaggedProducts(v);
            final hasProductMatch = tagged.any(
              (p) => (p['title'] ?? '').toString().toLowerCase().contains(q),
            );

            final matchesSearch = q.isEmpty ||
                caption.contains(q) ||
                username.contains(q) ||
                displayName.contains(q) ||
                hasProductMatch;

            if (!matchesSearch) return false;

            final status = (v['status'] ?? 'draft').toString();
            if (_filterStatus == 'draft') return status == 'draft';
            if (_filterStatus == 'published') return status == 'published';
            if (_filterStatus == 'blocked') return status == 'blocked';
            if (_filterStatus == 'tagged') return tagged.isNotEmpty;
            return true;
          }).toList();

          return AdminLayout(
            title: 'Kiểm Duyệt & Quản Lý Video Đăng Tải',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 KPI Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Tổng Video Hệ Thống',
                        value: '${allVideos.length}',
                        subtitle: 'Video người dùng & Creator tải lên',
                        icon: Icons.video_library_rounded,
                        color: AdminPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Chờ Kiểm Duyệt',
                        value: '$pendingCount',
                        subtitle: 'Cần Admin duyệt để lên Xu hướng',
                        icon: Icons.hourglass_top_rounded,
                        color: AdminPalette.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Đã Duyệt Hiển Thị',
                        value: '$publishedCount',
                        subtitle: 'Đang phát công khai trên bảng tin',
                        icon: Icons.verified_rounded,
                        color: AdminPalette.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Đã Chặn / Vi Phạm',
                        value: '$blockedCount',
                        subtitle: 'Bị từ chối hoặc ẩn khỏi cộng đồng',
                        icon: Icons.block_rounded,
                        color: AdminPalette.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search & Moderation Filter Toolbar (Responsive Wrap)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        height: 42,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText:
                                'Tìm theo caption, @username hoặc sản phẩm...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AdminPalette.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AdminPalette.textSecondary,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AdminPalette.border),
                            ),
                          ),
                        ),
                      ),
                      _buildFilterPill('Tất cả (${allVideos.length})', 'all'),
                      _buildFilterPill('⏳ Chờ duyệt ($pendingCount)', 'draft'),
                      _buildFilterPill('✅ Đã duyệt ($publishedCount)', 'published'),
                      _buildFilterPill('🚫 Đã chặn ($blockedCount)', 'blocked'),
                      _buildFilterPill('🛍️ Có gắn SP', 'tagged'),
                      if (pendingCount > 0)
                        ElevatedButton.icon(
                          onPressed: () {
                            context
                                .read<AdminBloc>()
                                .add(AdminApproveAllPendingVideos());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã phê duyệt toàn bộ $pendingCount video đang chờ!',
                                ),
                                backgroundColor: AdminPalette.success,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminPalette.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: Text(
                            'Duyệt Tất Cả ($pendingCount)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Videos Moderation Table
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: state.status == AdminStatus.loading && allVideos.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredVideos.isEmpty
                            ? _buildEmptyState()
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 1020),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(
                                          const Color(0xFFF8FAFC),
                                        ),
                                        headingRowHeight: 50,
                                        dataRowMinHeight: 92,
                                        dataRowMaxHeight: 106,
                                        horizontalMargin: 24,
                                        columnSpacing: 22,
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'VIDEO PREVIEW',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'NGƯỜI ĐĂNG & MÔ TẢ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'SẢN PHẨM GẮN KÈM',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'TƯƠNG TÁC',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'TRẠNG THÁI DUYỆT',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'QUYẾT ĐỊNH KIỂM DUYỆT',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AdminPalette.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: filteredVideos.map((video) {
                                          final status =
                                              (video['status'] ?? 'draft').toString();
                                          final profile = video['profiles'] is Map
                                              ? Map<String, dynamic>.from(
                                                  video['profiles'] as Map,
                                                )
                                              : <String, dynamic>{};
                                          final rawUsername =
                                              (profile['username'] ?? '').toString().trim();
                                          final username =
                                              rawUsername.isNotEmpty ? rawUsername : 'creator';
                                          final rawDisplayName =
                                              (profile['display_name'] ?? '').toString().trim();
                                          final displayName = rawDisplayName.isNotEmpty
                                              ? rawDisplayName
                                              : username;
                                          final initial = displayName.isNotEmpty
                                              ? displayName.substring(0, 1).toUpperCase()
                                              : 'U';
                                          final avatarUrl =
                                              _validImageUrl(profile['avatar_url']);
                                          final isVerified =
                                              profile['is_verified'] == true;
                                          final thumbUrl =
                                              _validImageUrl(video['thumbnail_path']);
                                          final durationStr = _formatDuration(
                                            (video['duration_ms'] as num?)?.toInt(),
                                          );
                                          final createdAt = video['created_at'] != null
                                              ? DateTime.tryParse(
                                                  video['created_at'].toString(),
                                                )
                                              : null;
                                          final taggedProducts =
                                              _extractTaggedProducts(video);

                                          return DataRow(
                                            cells: [
                                              // Col 1: Thumbnail 9:16 with Play Overlay
                                              DataCell(
                                                InkWell(
                                                  onTap: () =>
                                                      _showVideoPreviewModal(
                                                    context,
                                                    video,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Container(
                                                        width: 56,
                                                        height: 78,
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFF0F172A,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            10,
                                                          ),
                                                          border: Border.all(
                                                            color:
                                                                AdminPalette.border,
                                                          ),
                                                          image: thumbUrl != null
                                                              ? DecorationImage(
                                                                  image: NetworkImage(
                                                                    thumbUrl,
                                                                  ),
                                                                  fit: BoxFit.cover,
                                                                )
                                                              : null,
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 26,
                                                        height: 26,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withValues(alpha: 0.55),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.play_arrow_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 4,
                                                        right: 4,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 1,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black
                                                                .withValues(alpha: 0.7),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                              4,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            durationStr,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 9.5,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // Col 2: Author + Caption
                                              DataCell(
                                                SizedBox(
                                                  width: 270,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 11,
                                                            backgroundColor:
                                                                AdminPalette.primary,
                                                            backgroundImage:
                                                                avatarUrl != null
                                                                    ? NetworkImage(
                                                                        avatarUrl,
                                                                      )
                                                                    : null,
                                                            child: avatarUrl == null
                                                                ? Text(
                                                                    initial,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize: 10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  )
                                                                : null,
                                                          ),
                                                          const SizedBox(width: 7),
                                                          Flexible(
                                                            child: Text(
                                                              '@$username',
                                                              style:
                                                                  const TextStyle(
                                                                fontWeight:
                                                                    FontWeight.w800,
                                                                fontSize: 12.5,
                                                                color: AdminPalette
                                                                    .textPrimary,
                                                              ),
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                          ),
                                                          if (isVerified) ...[
                                                            const SizedBox(width: 4),
                                                            const Icon(
                                                              Icons.verified_rounded,
                                                              size: 14,
                                                              color:
                                                                  AdminPalette.info,
                                                            ),
                                                          ],
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            AdminFormatters
                                                                .formatDateTime(
                                                              createdAt,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AdminPalette
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        (video['caption'] ?? '')
                                                                .toString()
                                                                .trim()
                                                                .isEmpty
                                                            ? 'Không có mô tả'
                                                            : video['caption']
                                                                .toString(),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          color: AdminPalette
                                                              .textSecondary,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // Col 3: Tagged Products
                                              DataCell(
                                                taggedProducts.isEmpty
                                                    ? const Text(
                                                        'Không gắn sản phẩm',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: AdminPalette
                                                              .textSecondary,
                                                        ),
                                                      )
                                                    : SizedBox(
                                                        width: 210,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                  0xFFFF6B00,
                                                                ).withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  6,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .shopping_bag_rounded,
                                                                    size: 13,
                                                                    color: Color(
                                                                      0xFFFF6B00,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    'Gắn ${taggedProducts.length} sản phẩm',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize: 11.5,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: Color(
                                                                        0xFFFF6B00,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              (taggedProducts.first[
                                                                          'title'] ??
                                                                      '')
                                                                  .toString(),
                                                              maxLines: 1,
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.w600,
                                                                color: AdminPalette
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                              ),

                                              // Col 4: Stats
                                              DataCell(
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '👁️ ${video['view_count'] ?? 0} lượt xem',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: AdminPalette
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '❤️ ${video['like_count'] ?? 0}  •  💬 ${video['comment_count'] ?? 0}',
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color: AdminPalette
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Col 5: Moderation Status Badge
                                              DataCell(
                                                _buildVideoStatusBadge(status),
                                              ),

                                              // Col 6: Quick Moderation Actions
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    _buildIconBtn(
                                                      tooltip:
                                                          'Xem video & kiểm tra nội dung',
                                                      icon: Icons
                                                          .play_circle_outline_rounded,
                                                      color: AdminPalette.primary,
                                                      onTap: () =>
                                                          _showVideoPreviewModal(
                                                        context,
                                                        video,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (status != 'published') ...[
                                                      ElevatedButton.icon(
                                                        onPressed: () {
                                                          context
                                                              .read<AdminBloc>()
                                                              .add(
                                                                AdminUpdateVideoStatus(
                                                                  videoId:
                                                                      video['id'],
                                                                  status:
                                                                      'published',
                                                                ),
                                                              );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Đã duyệt đăng video của @$username lên Xu hướng! ✅',
                                                              ),
                                                              backgroundColor:
                                                                  AdminPalette
                                                                      .success,
                                                            ),
                                                          );
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              AdminPalette.success,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 10,
                                                            vertical: 8,
                                                          ),
                                                          minimumSize: Size.zero,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(8),
                                                          ),
                                                          elevation: 0,
                                                        ),
                                                        icon: const Icon(
                                                          Icons.check_rounded,
                                                          size: 15,
                                                        ),
                                                        label: const Text(
                                                          'Duyệt',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    if (status != 'blocked') ...[
                                                      _buildIconBtn(
                                                        tooltip:
                                                            'Từ chối / Khóa video vi phạm',
                                                        icon: Icons.block_rounded,
                                                        color: AdminPalette.danger,
                                                        onTap: () {
                                                          context
                                                              .read<AdminBloc>()
                                                              .add(
                                                                AdminUpdateVideoStatus(
                                                                  videoId:
                                                                      video['id'],
                                                                  status: 'blocked',
                                                                ),
                                                              );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Đã chặn video của @$username khỏi bảng tin! 🚫',
                                                              ),
                                                              backgroundColor:
                                                                  AdminPalette
                                                                      .danger,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    _buildIconBtn(
                                                      tooltip: 'Xóa vĩnh viễn video',
                                                      icon:
                                                          Icons.delete_outline_rounded,
                                                      color: AdminPalette
                                                          .textSecondary,
                                                      onTap: () =>
                                                          _confirmDeleteVideo(
                                                        context,
                                                        video,
                                                      ),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoStatusBadge(String status) {
    switch (status) {
      case 'published':
        return const AdminStatusBadge(
          label: 'Đã duyệt đăng',
          color: AdminPalette.success,
          icon: Icons.check_circle_rounded,
        );
      case 'blocked':
        return const AdminStatusBadge(
          label: 'Đã chặn vi phạm',
          color: AdminPalette.danger,
          icon: Icons.block_rounded,
        );
      case 'draft':
      default:
        return const AdminStatusBadge(
          label: 'Chờ kiểm duyệt',
          color: AdminPalette.warning,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }

  Widget _buildFilterPill(String label, String value) {
    final selected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildIconBtn({
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

  Widget _buildEmptyState() {
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
              Icons.video_collection_outlined,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có video nào trong danh mục này',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khi người dùng đăng tải video mới từ ứng dụng, video sẽ xuất hiện tại đây để bạn kiểm duyệt.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteVideo(BuildContext parentContext, Map<String, dynamic> video) {
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận xóa vĩnh viễn video?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Video này sẽ bị gỡ bỏ vĩnh viễn khỏi hệ thống và không thể khôi phục.',
          style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              parentContext.read<AdminBloc>().add(
                    AdminUpdateVideoStatus(
                      videoId: video['id'],
                      status: 'deleted',
                    ),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa video khỏi hệ thống!'),
                  backgroundColor: AdminPalette.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa Vĩnh Viễn'),
          ),
        ],
      ),
    );
  }

  void _showVideoPreviewModal(
    BuildContext parentContext,
    Map<String, dynamic> video,
  ) {
    final taggedProducts = _extractTaggedProducts(video);
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return _VideoModerationPreviewDialog(
          video: video,
          taggedProducts: taggedProducts,
          onUpdateStatus: (newStatus) {
            parentContext.read<AdminBloc>().add(
                  AdminUpdateVideoStatus(
                    videoId: video['id'],
                    status: newStatus,
                  ),
                );
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text(
                  newStatus == 'published'
                      ? 'Đã duyệt đăng video lên Xu hướng! ✅'
                      : 'Đã chặn video vi phạm! 🚫',
                ),
                backgroundColor: newStatus == 'published'
                    ? AdminPalette.success
                    : AdminPalette.danger,
              ),
            );
          },
        );
      },
    );
  }
}

class _VideoModerationPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final List<Map<String, dynamic>> taggedProducts;
  final void Function(String newStatus) onUpdateStatus;

  const _VideoModerationPreviewDialog({
    required this.video,
    required this.taggedProducts,
    required this.onUpdateStatus,
  });

  @override
  State<_VideoModerationPreviewDialog> createState() =>
      _VideoModerationPreviewDialogState();
}

class _VideoModerationPreviewDialogState
    extends State<_VideoModerationPreviewDialog> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  String? _validImageUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:')) {
      return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = (widget.video['video_path'] ?? '').toString().trim();
    if (!url.startsWith('http')) {
      setState(() => _hasError = true);
      return;
    }
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.video['profiles'] is Map
        ? Map<String, dynamic>.from(widget.video['profiles'] as Map)
        : <String, dynamic>{};
    final rawUsername = (profile['username'] ?? '').toString().trim();
    final username = rawUsername.isNotEmpty ? rawUsername : 'creator';
    final rawDisplayName = (profile['display_name'] ?? '').toString().trim();
    final displayName = rawDisplayName.isNotEmpty ? rawDisplayName : username;
    final initial =
        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U';
    final avatarUrl = _validImageUrl(profile['avatar_url']);
    final status = (widget.video['status'] ?? 'draft').toString();
    final thumbUrl = _validImageUrl(widget.video['thumbnail_path']);
    final videoUrl = (widget.video['video_path'] ?? '').toString().trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 780,
        height: 540,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Left: 9:16 Video Player Preview
            Container(
              width: 310,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_initialized && _controller != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio > 0
                            ? _controller!.value.aspectRatio
                            : 9 / 16,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  else if (thumbUrl != null)
                    Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  if (!_initialized && !_hasError)
                    const CircularProgressIndicator(color: Colors.white),
                  if (_initialized &&
                      _controller != null &&
                      !_controller!.value.isPlaying)
                    IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 14,
                    left: 14,
                    right: 14,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(videoUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text(
                        'Mở file Video gốc',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right: Video Details, Tagged Products & Moderation Controls
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kiểm Duyệt Nội Dung Video',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AdminPalette.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Creator Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AdminPalette.primary,
                          backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  color: AdminPalette.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdminStatusBadge(
                          label: status == 'published'
                              ? 'Đã duyệt'
                              : status == 'blocked'
                                  ? 'Đã chặn'
                                  : 'Chờ duyệt',
                          color: status == 'published'
                              ? AdminPalette.success
                              : status == 'blocked'
                                  ? AdminPalette.danger
                                  : AdminPalette.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Caption Box
                    const Text(
                      'MÔ TẢ VIDEO & HASHTAG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AdminPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminPalette.border),
                      ),
                      child: Text(
                        (widget.video['caption'] ?? '').toString().trim().isEmpty
                            ? 'Không có mô tả'
                            : widget.video['caption'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AdminPalette.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tagged Products List
                    Text(
                      'SẢN PHẨM GẮN KÈM TRONG VIDEO (${widget.taggedProducts.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AdminPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: widget.taggedProducts.isEmpty
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminPalette.border),
                              ),
                              child: const Text(
                                'Video này không gắn link sản phẩm nào.',
                                style: TextStyle(
                                  color: AdminPalette.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: widget.taggedProducts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final p = widget.taggedProducts[idx];
                                final price =
                                    (p['price_min'] as num?)?.toDouble() ?? 0;
                                final pCover = _validImageUrl(p['cover_path']);
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AdminPalette.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: const Color(0xFFF1F5F9),
                                          image: pCover != null
                                              ? DecorationImage(
                                                  image: NetworkImage(pCover),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (p['title'] ?? 'Sản phẩm')
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              AdminFormatters.formatVnd(price),
                                              style: const TextStyle(
                                                color: AdminPalette.danger,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom Moderation Decision Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onUpdateStatus('blocked'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminPalette.danger,
                              side: const BorderSide(color: AdminPalette.danger),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text(
                              'Từ Chối / Chặn Video',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => widget.onUpdateStatus('published'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminPalette.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Duyệt Cho Lên Xu Hướng',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
