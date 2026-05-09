import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_layout.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_event.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_state.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc()..add(AdminFetchShops()),
      child: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state.status == AdminStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return AdminLayout(
            title: 'Quản lý Thương hiệu & Nhãn hàng 🏷️',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách tất cả các đối tác nhãn hàng trên hệ thống Shareco',
                      style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showShopFormModal(context, null),
                      icon: const Icon(Icons.add_business_rounded, size: 18),
                      label: const Text('Tạo nhãn hàng mới', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Shops List Container
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: state.status == AdminStatus.loading
                          ? const Center(child: CircularProgressIndicator())
                          : state.shops.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Chưa có nhãn hàng nào được tạo.',
                                    style: TextStyle(color: Colors.black45, fontSize: 16),
                                  ),
                                )
                              : ListView(
                                  children: [
                                    _buildShopsTableHeader(),
                                    const Divider(),
                                    ...state.shops.map((shop) => _buildShopRow(context, shop)),
                                  ],
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

  Widget _buildShopsTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('THƯƠNG HIỆU / BRAND', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 4, child: Text('MÔ TẢ CHI TIẾT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 2, child: Text('CHỈ SỐ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 1, child: Text('TRẠNG THÁI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 1, child: Text('THAO TÁC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildShopRow(BuildContext context, Map<String, dynamic> shop) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1))),
      ),
      child: Row(
        children: [
          // Brand Logo + Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    shop['logo_path'] ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.store, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop['shop_name'] ?? 'Tên nhãn hàng',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'slug: ${shop['shop_slug'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.black38, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Description
          Expanded(
            flex: 4,
            child: Text(
              shop['description'] ?? 'Không có mô tả.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Metrics
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${shop['rating_avg'] ?? 5.0} (${shop['rating_count'] ?? 0} đánh giá)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${shop['follower_count'] ?? 0} followers',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (shop['status'] == 'active') ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (shop['status'] == 'active') ? Colors.green.shade200 : Colors.grey.shade300,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                (shop['status'] == 'active') ? 'Hoạt động' : 'Tạm dừng',
                style: TextStyle(
                  color: (shop['status'] == 'active') ? Colors.green.shade700 : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Action button
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6200EE)),
                hoverColor: const Color(0xFF6200EE).withOpacity(0.05),
                onPressed: () => _showShopFormModal(context, shop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShopFormModal(BuildContext parentContext, Map<String, dynamic>? shop) {
    final isEdit = shop != null;
    final nameCtrl = TextEditingController(text: isEdit ? shop['shop_name'] : '');
    final descCtrl = TextEditingController(text: isEdit ? shop['description'] : '');
    final logoCtrl = TextEditingController(text: isEdit ? shop['logo_path'] : '');
    final coverCtrl = TextEditingController(text: isEdit ? shop['cover_path'] : '');

    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEdit ? 'Cập nhật thông tin nhãn hàng 📝' : 'Tạo nhãn hàng mới 🚀',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 450),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên nhãn hàng *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả ngắn gọn về thương hiệu *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: logoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link ảnh đại diện (Logo) URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                      hintText: 'https://images.unsplash.com/...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: coverCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link ảnh bìa (Cover Banner) URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wallpaper),
                      hintText: 'https://images.unsplash.com/...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Vui lòng điền đầy đủ các thông tin bắt buộc (*).')),
                  );
                  return;
                }

                if (isEdit) {
                  parentContext.read<AdminBloc>().add(AdminUpdateShop(
                        id: shop['id'],
                        shopName: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        logoPath: logoCtrl.text.trim().isNotEmpty ? logoCtrl.text.trim() : null,
                        coverPath: coverCtrl.text.trim().isNotEmpty ? coverCtrl.text.trim() : null,
                      ));
                } else {
                  parentContext.read<AdminBloc>().add(AdminCreateShop(
                        shopName: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        logoPath: logoCtrl.text.trim().isNotEmpty ? logoCtrl.text.trim() : null,
                        coverPath: coverCtrl.text.trim().isNotEmpty ? coverCtrl.text.trim() : null,
                      ));
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Cập nhật nhãn hàng thành công!' : 'Tạo mới nhãn hàng thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE),
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo ngay', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
