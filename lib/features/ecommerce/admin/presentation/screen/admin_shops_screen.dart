import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'pending', 'active', 'verified', 'rejected_blocked'

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminBloc()..add(AdminFetchShops()),
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
          final allShops = state.shops;
          final pendingCount =
              allShops.where((s) => (s['status'] ?? 'active') == 'pending').length;
          final activeCount =
              allShops.where((s) => (s['status'] ?? 'active') == 'active').length;
          final verifiedCount =
              allShops.where((s) => s['is_verified'] == true).length;
          final rejectedBlockedCount = allShops
              .where((s) => s['status'] == 'rejected' || s['status'] == 'blocked')
              .length;

          final filteredShops = allShops.where((s) {
            final name = (s['shop_name'] ?? '').toString().toLowerCase();
            final slug = (s['shop_slug'] ?? '').toString().toLowerCase();
            final desc = (s['description'] ?? '').toString().toLowerCase();
            final owner = (s['profiles'] is Map ? (s['profiles']['display_name'] ?? '') : '').toString().toLowerCase();
            final q = _searchQuery.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                name.contains(q) ||
                slug.contains(q) ||
                desc.contains(q) ||
                owner.contains(q);

            if (!matchesSearch) return false;

            final status = s['status'] ?? 'active';
            final isVerified = s['is_verified'] == true;
            if (_filterStatus == 'pending') return status == 'pending';
            if (_filterStatus == 'active') return status == 'active';
            if (_filterStatus == 'verified') return isVerified;
            if (_filterStatus == 'rejected_blocked') {
              return status == 'rejected' || status == 'blocked';
            }
            return true;
          }).toList();

          return AdminLayout(
            title: 'Kiểm Duyệt & Phê Duyệt Hồ Sơ Gian Hàng',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Summary Row
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Đơn Chờ Xét Duyệt',
                        value: '$pendingCount',
                        subtitle: 'Hồ sơ người dùng nộp cần duyệt',
                        icon: Icons.pending_actions_rounded,
                        color: pendingCount > 0
                            ? const Color(0xFFF97316)
                            : AdminPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Gian Hàng Đang Bán',
                        value: '$activeCount',
                        subtitle: 'Đang hoạt động trên sàn TikTok Shop',
                        icon: Icons.storefront_rounded,
                        color: AdminPalette.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Thương Hiệu Tích Xanh',
                        value: '$verifiedCount',
                        subtitle: 'Official Brand Mall xác thực uy tín',
                        icon: Icons.verified_rounded,
                        color: AdminPalette.info,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminKpiCard(
                        title: 'Từ Chối / Tạm Khóa',
                        value: '$rejectedBlockedCount',
                        subtitle: 'Vi phạm chính sách hoặc hồ sơ lỗi',
                        icon: Icons.block_rounded,
                        color: AdminPalette.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search & Filter Toolbar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: Row(
                    children: [
                      // Search Input
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Tìm theo tên gian hàng, chủ shop, slug hoặc địa chỉ...',
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

                      // Filter Chips
                      _buildFilterPill('Tất cả (${allShops.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        'Chờ duyệt ($pendingCount)',
                        'pending',
                        isHighlight: pendingCount > 0,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill('Đang hoạt động ($activeCount)', 'active'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Tích xanh ($verifiedCount)', 'verified'),
                      const SizedBox(width: 8),
                      _buildFilterPill('Từ chối / Khóa ($rejectedBlockedCount)', 'rejected_blocked'),
                      const SizedBox(width: 12),

                      // Refresh button
                      Tooltip(
                        message: 'Tải lại danh sách đơn duyệt',
                        child: InkWell(
                          onTap: () => context.read<AdminBloc>().add(AdminFetchShops()),
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

                // Main Shops Table Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: state.status == AdminStatus.loading && allShops.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredShops.isEmpty
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
                                      dataRowMinHeight: 76,
                                      dataRowMaxHeight: 88,
                                      horizontalMargin: 20,
                                      columnSpacing: 18,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'GIAN HÀNG',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'NGƯỜI ĐĂNG KÝ (SELLER)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'KHO LẤY HÀNG',
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
                                            'HÀNH ĐỘNG KIỂM DUYỆT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: AdminPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredShops.map((shop) {
                                        final status = shop['status'] ?? 'active';
                                        final isPending = status == 'pending';
                                        final isActive = status == 'active';
                                        final isRejected = status == 'rejected';
                                        final isVerified = shop['is_verified'] == true;

                                        // Owner profile info
                                        final profile = shop['profiles'] is Map ? shop['profiles'] as Map : null;
                                        final ownerName = profile?['display_name'] ?? shop['owner_name'] ?? 'Chưa xác định';
                                        final ownerUsername = profile?['username'] ?? shop['owner_username'] ?? 'seller';
                                        final ownerPhone = profile?['phone_number'] ?? shop['owner_phone'] ?? '';
                                        final ownerAvatar = profile?['avatar_url'];

                                        // Warehouse info
                                        final province = shop['pickup_province'] ?? '';
                                        final district = shop['pickup_district'] ?? '';
                                        final address = shop['pickup_address'] ?? '';

                                        return DataRow(
                                          cells: [
                                            // Col 1: Shop details
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: AdminPalette.border,
                                                      ),
                                                      color: const Color(0xFFF1F5F9),
                                                      image: shop['logo_path'] != null
                                                          ? DecorationImage(
                                                              image: NetworkImage(
                                                                shop['logo_path'],
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child: shop['logo_path'] == null
                                                        ? const Icon(
                                                            Icons.store_rounded,
                                                            color: AdminPalette.textSecondary,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            shop['shop_name'] ?? 'Chưa đặt tên',
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 14,
                                                              color: AdminPalette.textPrimary,
                                                            ),
                                                          ),
                                                          if (isVerified) ...[
                                                            const SizedBox(width: 5),
                                                            const Tooltip(
                                                              message: 'Official Brand Mall (Chính Hãng)',
                                                              child: Icon(
                                                                Icons.verified_rounded,
                                                                color: AdminPalette.info,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '@${shop['shop_slug'] ?? 'shop'}',
                                                        style: const TextStyle(
                                                          color: AdminPalette.textSecondary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Col 2: Owner / Seller
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 17,
                                                    backgroundColor: const Color(0xFFE2E8F0),
                                                    backgroundImage: ownerAvatar != null
                                                        ? NetworkImage(ownerAvatar)
                                                        : null,
                                                    child: ownerAvatar == null
                                                        ? const Icon(Icons.person_rounded, size: 18, color: AdminPalette.textSecondary)
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        ownerName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: AdminPalette.textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        ownerPhone.isNotEmpty
                                                            ? '$ownerPhone (@$ownerUsername)'
                                                            : '@$ownerUsername',
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

                                            // Col 3: Warehouse
                                            DataCell(
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.location_on_rounded, size: 14, color: AdminPalette.primary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        province.isNotEmpty
                                                            ? (district.isNotEmpty ? '$district, $province' : province)
                                                            : 'Chưa cập nhật',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 12.5,
                                                          color: AdminPalette.textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (address.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    SizedBox(
                                                      width: 180,
                                                      child: Text(
                                                        address,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AdminPalette.textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            // Col 4: Status Badge
                                            DataCell(
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (isPending)
                                                    const AdminStatusBadge(
                                                      label: 'Chờ xét duyệt ⏳',
                                                      color: Color(0xFFF97316),
                                                    )
                                                  else if (isActive)
                                                    const AdminStatusBadge(
                                                      label: 'Đang hoạt động ✅',
                                                      color: AdminPalette.success,
                                                    )
                                                  else if (isRejected)
                                                    const AdminStatusBadge(
                                                      label: 'Bị từ chối ❌',
                                                      color: AdminPalette.danger,
                                                    )
                                                  else
                                                    const AdminStatusBadge(
                                                      label: 'Tạm khóa 🔒',
                                                      color: AdminPalette.danger,
                                                    ),
                                                  if (isRejected && shop['rejection_reason'] != null) ...[
                                                    const SizedBox(height: 3),
                                                    SizedBox(
                                                      width: 140,
                                                      child: Text(
                                                        shop['rejection_reason'],
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
                                                  // View details modal
                                                  _buildActionButton(
                                                    tooltip: 'Xem hồ sơ chi tiết',
                                                    icon: Icons.visibility_outlined,
                                                    color: AdminPalette.textPrimary,
                                                    onTap: () => _showShopDetailsDialog(context, shop),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // If pending: Show Approve & Reject buttons
                                                  if (isPending) ...[
                                                    ElevatedButton.icon(
                                                      onPressed: () => _confirmApproveShop(context, shop),
                                                      icon: const Icon(Icons.check_rounded, size: 15),
                                                      label: const Text('Duyệt Shop'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AdminPalette.success,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                        textStyle: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    OutlinedButton.icon(
                                                      onPressed: () => _showRejectDialog(context, shop),
                                                      icon: const Icon(Icons.close_rounded, size: 15),
                                                      label: const Text('Từ chối'),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: AdminPalette.danger,
                                                        side: const BorderSide(color: AdminPalette.danger),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                        textStyle: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    // Toggle Verified badge
                                                    _buildActionButton(
                                                      tooltip: isVerified
                                                          ? 'Hạ cấp: Gỡ tích xanh Mall'
                                                          : 'Cấp tích xanh Official Mall',
                                                      icon: isVerified
                                                          ? Icons.verified_rounded
                                                          : Icons.verified_outlined,
                                                      color: isVerified
                                                          ? AdminPalette.info
                                                          : AdminPalette.textSecondary,
                                                      onTap: () {
                                                        context.read<AdminBloc>().add(
                                                              AdminToggleShopVerified(
                                                                shopId: shop['id'],
                                                                isVerified: !isVerified,
                                                              ),
                                                            );
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              !isVerified
                                                                  ? 'Đã cấp tích xanh Official cho [${shop['shop_name']}]!'
                                                                  : 'Đã gỡ tích xanh của [${shop['shop_name']}].',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 6),

                                                    // Toggle Lock/Unlock
                                                    _buildActionButton(
                                                      tooltip: isActive
                                                          ? 'Đình chỉ / Tạm khóa gian hàng'
                                                          : 'Kích hoạt / Mở lại gian hàng',
                                                      icon: isActive
                                                          ? Icons.lock_open_rounded
                                                          : Icons.lock_outline_rounded,
                                                      color: isActive
                                                          ? const Color(0xFFF97316)
                                                          : AdminPalette.danger,
                                                      onTap: () {
                                                        final nextStatus =
                                                            isActive ? 'blocked' : 'active';
                                                        context.read<AdminBloc>().add(
                                                              AdminToggleShopStatus(
                                                                shopId: shop['id'],
                                                                status: nextStatus,
                                                              ),
                                                            );
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              nextStatus == 'blocked'
                                                                  ? 'Đã tạm khóa gian hàng [${shop['shop_name']}] do vi phạm!'
                                                                  : 'Đã mở lại hoạt động cho [${shop['shop_name']}]!',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 6),

                                                    // Edit details
                                                    _buildActionButton(
                                                      tooltip: 'Cập nhật thông tin gian hàng',
                                                      icon: Icons.edit_outlined,
                                                      color: AdminPalette.primary,
                                                      onTap: () => _showEditShopDialog(
                                                        context,
                                                        shopToEdit: shop,
                                                      ),
                                                    ),
                                                  ],
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

  Widget _buildFilterPill(String label, String value, {bool isHighlight = false}) {
    final selected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AdminPalette.primary.withValues(alpha: 0.1)
              : (isHighlight
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AdminPalette.primary
                : (isHighlight ? const Color(0xFFF97316) : AdminPalette.border),
            width: isHighlight ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AdminPalette.primary
                : (isHighlight ? const Color(0xFFC2410C) : AdminPalette.textSecondary),
            fontWeight: (selected || isHighlight) ? FontWeight.w700 : FontWeight.w600,
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
              Icons.storefront_outlined,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có hồ sơ gian hàng nào phù hợp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Người dùng sẽ xuất hiện ở đây khi nộp đơn Đăng ký bán hàng từ ứng dụng.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _confirmApproveShop(BuildContext context, Map<String, dynamic> shop) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminPalette.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AdminPalette.success),
            ),
            const SizedBox(width: 12),
            const Text(
              'Xác Nhận Phê Duyệt',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn phê duyệt gian hàng [${shop['shop_name']}] không?\nSau khi duyệt, người bán có thể đăng sản phẩm, livestream và bắt đầu bán hàng.',
          style: const TextStyle(height: 1.5, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Xem lại'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminBloc>().add(AdminApproveShop(shopId: shop['id']));
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã phê duyệt thành công gian hàng [${shop['shop_name']}]!'),
                  backgroundColor: AdminPalette.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Phê Duyệt Ngay'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Map<String, dynamic> shop) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminPalette.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, color: AdminPalette.danger),
            ),
            const SizedBox(width: 12),
            const Text(
              'Từ Chối Đơn Đăng Ký',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập lý do từ chối gian hàng [${shop['shop_name']}]. Lý do này sẽ được gửi trực tiếp cho người bán để khắc phục:',
                style: const TextStyle(fontSize: 13, height: 1.4, color: AdminPalette.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'VD: Địa chỉ kho không rõ ràng, tên thương hiệu trùng lặp...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickReasonChip('Địa chỉ kho không chính xác', reasonController),
                  _buildQuickReasonChip('Tên shop vi phạm nhãn hiệu', reasonController),
                  _buildQuickReasonChip('Thiếu số điện thoại liên hệ', reasonController),
                  _buildQuickReasonChip('Hàng hóa không rõ nguồn gốc', reasonController),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối!')),
                );
                return;
              }
              context.read<AdminBloc>().add(
                    AdminRejectShop(shopId: shop['id'], reason: reason),
                  );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã từ chối đơn đăng ký gian hàng [${shop['shop_name']}].'),
                  backgroundColor: AdminPalette.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Gửi Lý Do & Từ Chối'),
          ),
        ],
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

  void _showShopDetailsDialog(BuildContext context, Map<String, dynamic> shop) {
    final profile = shop['profiles'] is Map ? shop['profiles'] as Map : null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminPalette.border),
                image: shop['logo_path'] != null
                    ? DecorationImage(
                        image: NetworkImage(shop['logo_path']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: shop['logo_path'] == null
                  ? const Icon(Icons.store_rounded, color: AdminPalette.textSecondary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop['shop_name'] ?? 'Gian hàng',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  Text(
                    '@${shop['shop_slug'] ?? 'shop'}',
                    style: const TextStyle(fontSize: 12, color: AdminPalette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Trạng thái:', shop['status'] ?? 'active'),
                _buildDetailRow('Tích xanh Mall:', shop['is_verified'] == true ? 'Đã xác thực Official Mall' : 'Chưa cấp tích xanh'),
                _buildDetailRow('Người nộp đơn:', profile?['display_name'] ?? shop['owner_name'] ?? 'N/A'),
                _buildDetailRow('Tài khoản:', '@${profile?['username'] ?? shop['owner_username'] ?? 'N/A'}'),
                _buildDetailRow('SĐT Liên hệ:', profile?['phone_number'] ?? shop['owner_phone'] ?? 'Chưa cung cấp'),
                _buildDetailRow('Kho lấy hàng:', '${shop['pickup_address'] ?? ''}, ${shop['pickup_district'] ?? ''}, ${shop['pickup_province'] ?? ''}'),
                _buildDetailRow('Mô tả gian hàng:', shop['description'] ?? 'Chưa có mô tả'),
                if (shop['rejection_reason'] != null)
                  _buildDetailRow('Lý do từ chối gần nhất:', shop['rejection_reason'], isDanger: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AdminPalette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDanger ? AdminPalette.danger : AdminPalette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditShopDialog(BuildContext parentContext, {required Map<String, dynamic> shopToEdit}) {
    final nameController = TextEditingController(text: shopToEdit['shop_name']);
    final descController = TextEditingController(text: shopToEdit['description']);
    final String? existingLogoUrl = shopToEdit['logo_path'];

    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                setStateDialog(() {
                  selectedImageBytes = bytes;
                  selectedImageName = pickedFile.name;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Cập Nhật Thông Tin Gian Hàng',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Logo Nhận Diện Thương Hiệu',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AdminPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          InkWell(
                            onTap: pickImage,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AdminPalette.border),
                                image: selectedImageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(selectedImageBytes!),
                                        fit: BoxFit.cover,
                                      )
                                    : (existingLogoUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(existingLogoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                              ),
                              child: (selectedImageBytes == null && existingLogoUrl == null)
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: AdminPalette.primary,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Tải ảnh',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AdminPalette.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: pickImage,
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text('Đổi ảnh logo'),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Khuyến nghị ảnh vuông 500x500px (PNG, JPG).',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AdminPalette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên Gian Hàng',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả & Giới thiệu',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Hủy bỏ'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final desc = descController.text.trim();
                          if (name.isEmpty) return;

                          setStateDialog(() => isUploading = true);

                          String? finalLogoUrl = existingLogoUrl;
                          if (selectedImageBytes != null && selectedImageName != null) {
                            finalLogoUrl = await AdminStorageHelper.uploadImage(
                              bytes: selectedImageBytes!,
                              originalFileName: selectedImageName!,
                              prefix: 'shop_logo',
                            );
                          }

                          if (!parentContext.mounted) return;
                          parentContext.read<AdminBloc>().add(
                                AdminUpdateShop(
                                  id: shopToEdit['id'],
                                  shopName: name,
                                  description: desc,
                                  logoPath: finalLogoUrl,
                                ),
                              );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Lưu Thay Đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}