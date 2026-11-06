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
  String _filterStatus = 'all'; // 'all', 'active', 'verified', 'blocked'

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
          final activeCount =
              allShops.where((s) => (s['status'] ?? 'active') == 'active').length;
          final verifiedCount =
              allShops.where((s) => s['is_verified'] == true).length;

          final filteredShops = allShops.where((s) {
            final name = (s['shop_name'] ?? '').toString().toLowerCase();
            final slug = (s['shop_slug'] ?? '').toString().toLowerCase();
            final desc = (s['description'] ?? '').toString().toLowerCase();
            final q = _searchQuery.trim().toLowerCase();
            final matchesSearch =
                q.isEmpty || name.contains(q) || slug.contains(q) || desc.contains(q);

            if (!matchesSearch) return false;

            final status = s['status'] ?? 'active';
            final isVerified = s['is_verified'] == true;
            if (_filterStatus == 'active') return status == 'active';
            if (_filterStatus == 'verified') return isVerified;
            if (_filterStatus == 'blocked') return status == 'blocked';
            return true;
          }).toList();

          return AdminLayout(
            title: 'Quản Lý Nhãn Hàng & Đối Tác Chính Hãng',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // KPI Summary Row
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Tổng Nhãn Hàng Đối Tác',
                      value: '${allShops.length}',
                      subtitle: 'Gian hàng chính hãng trên sàn',
                      icon: Icons.storefront_rounded,
                      color: AdminPalette.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đang Hoạt Động',
                      value: '$activeCount',
                      subtitle: 'Đủ điều kiện mở bán & gắn video',
                      icon: Icons.check_circle_outline_rounded,
                      color: AdminPalette.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đã Cấp Tích Xanh',
                      value: '$verifiedCount',
                      subtitle: 'Official Brand Mall xác thực',
                      icon: Icons.verified_rounded,
                      color: AdminPalette.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Action Toolbar
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
                            hintText: 'Tìm theo tên nhãn hàng, mã slug hoặc mô tả...',
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
                    _buildFilterPill('Hoạt động ($activeCount)', 'active'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Tích xanh ($verifiedCount)', 'verified'),
                    const SizedBox(width: 16),

                    // Create Brand Button
                    ElevatedButton.icon(
                      onPressed: () => _showShopDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_business_rounded, size: 19),
                      label: const Text(
                        'Thêm Nhãn Hàng',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
                                    dataRowMinHeight: 74,
                                    dataRowMaxHeight: 82,
                                    horizontalMargin: 24,
                                    columnSpacing: 24,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'NHÃN HÀNG / GIAN HÀNG',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'MÔ TẢ CHÍNH HÃNG',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'ĐÁNH GIÁ & THEO DÕI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TRẠNG THÁI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'THAO TÁC',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: filteredShops.map((shop) {
                                      final isActive =
                                          (shop['status'] ?? 'active') == 'active';
                                      final isVerified = shop['is_verified'] == true;
                                      final rating =
                                          (shop['rating_avg'] as num?)?.toDouble() ?? 5.0;
                                      final followers =
                                          (shop['follower_count'] as num?)?.toInt() ?? 0;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 46,
                                                  height: 46,
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
                                                            message: 'Official Brand Mall',
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
                                                      '@${shop['shop_slug'] ?? 'brand'}',
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
                                          DataCell(
                                            SizedBox(
                                              width: 280,
                                              child: Text(
                                                shop['description'] ?? 'Chưa có mô tả',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AdminPalette.textSecondary,
                                                  fontSize: 13,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.star_rounded,
                                                      color: Color(0xFFF59E0B),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      rating.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '$followers người theo dõi',
                                                  style: const TextStyle(
                                                    color: AdminPalette.textSecondary,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            AdminStatusBadge(
                                              label: isActive ? 'Hoạt động' : 'Đã khóa',
                                              color: isActive
                                                  ? AdminPalette.success
                                                  : AdminPalette.danger,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildActionButton(
                                                  tooltip: 'Chỉnh sửa thông tin',
                                                  icon: Icons.edit_outlined,
                                                  color: AdminPalette.primary,
                                                  onTap: () => _showShopDialog(
                                                    context,
                                                    shopToEdit: shop,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildActionButton(
                                                  tooltip: isVerified
                                                      ? 'Gỡ tích xanh chính hãng'
                                                      : 'Cấp tích xanh chính hãng',
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
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          !isVerified
                                                              ? 'Đã cấp tích xanh cho [${shop['shop_name']}]!'
                                                              : 'Đã gỡ tích xanh của [${shop['shop_name']}].',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 6),
                                                _buildActionButton(
                                                  tooltip: isActive
                                                      ? 'Khóa gian hàng'
                                                      : 'Mở khóa gian hàng',
                                                  icon: isActive
                                                      ? Icons.lock_open_rounded
                                                      : Icons.lock_outline_rounded,
                                                  color: isActive
                                                      ? AdminPalette.warning
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
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          nextStatus == 'blocked'
                                                              ? 'Đã khóa gian hàng [${shop['shop_name']}]!'
                                                              : 'Đã mở khóa [${shop['shop_name']}]!',
                                                        ),
                                                      ),
                                                    );
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
    final selected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
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
              Icons.storefront_outlined,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy nhãn hàng phù hợp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thử thay đổi từ khóa tìm kiếm hoặc tạo nhãn hàng đối tác mới.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showShopDialog(BuildContext parentContext, {Map<String, dynamic>? shopToEdit}) {
    final isEdit = shopToEdit != null;
    final nameController =
        TextEditingController(text: isEdit ? shopToEdit['shop_name'] : '');
    final descController =
        TextEditingController(text: isEdit ? shopToEdit['description'] : '');
    final String? existingLogoUrl = isEdit ? shopToEdit['logo_path'] : null;

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
              title: Text(
                isEdit ? 'Chỉnh Sửa Nhãn Hàng' : 'Đăng Ký Nhãn Hàng Mới',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
                                  label: const Text('Chọn ảnh từ máy tính'),
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
                          labelText: 'Tên Nhãn Hàng (VD: L\'Oreal Paris Official)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả & Cam kết chính hãng',
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
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Vui lòng nhập tên nhãn hàng!'),
                              ),
                            );
                            return;
                          }

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
                          if (isEdit) {
                            parentContext.read<AdminBloc>().add(
                                  AdminUpdateShop(
                                    id: shopToEdit['id'],
                                    shopName: name,
                                    description: desc,
                                    logoPath: finalLogoUrl,
                                  ),
                                );
                          } else {
                            parentContext.read<AdminBloc>().add(
                                  AdminCreateShop(
                                    shopName: name,
                                    description: desc,
                                    logoPath: finalLogoUrl,
                                  ),
                                );
                          }

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
                      : Text(isEdit ? 'Lưu Thay Đổi' : 'Khởi Tạo Shop'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
