import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          Expanded(flex: 30, child: Text('THƯƠNG HIỆU / BRAND', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 40, child: Text('MÔ TẢ CHI TIẾT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 20, child: Text('CHỈ SỐ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 12, child: Text('TRẠNG THÁI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 15, child: Text('THAO TÁC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
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
            flex: 30,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop['shop_name'] ?? 'Tên nhãn hàng',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shop['has_blue_badge'] == true) ...[
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'Nhãn hàng uy tín đã xác minh',
                              child: Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
                            ),
                          ],
                        ],
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
            flex: 40,
            child: Text(
              shop['description'] ?? 'Không có mô tả.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Metrics
          Expanded(
            flex: 20,
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
            flex: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (shop['status'] == 'active')
                    ? Colors.green.shade50
                    : (shop['status'] == 'blocked' ? Colors.red.shade50 : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (shop['status'] == 'active')
                      ? Colors.green.shade200
                      : (shop['status'] == 'blocked' ? Colors.red.shade200 : Colors.grey.shade300),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                (shop['status'] == 'active')
                    ? 'Hoạt động'
                    : (shop['status'] == 'blocked' ? 'Đã khóa ⛔' : 'Tạm dừng'),
                style: TextStyle(
                  color: (shop['status'] == 'active')
                      ? Colors.green.shade700
                      : (shop['status'] == 'blocked' ? Colors.red.shade700 : Colors.grey.shade600),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Action button (Tích xanh + Khóa/Mở khóa + Sửa)
          Expanded(
            flex: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Toggle verified badge (Blue tick)
                Tooltip(
                  message: shop['has_blue_badge'] == true ? 'Gỡ tích xanh' : 'Cấp tích xanh',
                  child: IconButton(
                    icon: Icon(
                      shop['has_blue_badge'] == true ? Icons.verified_rounded : Icons.verified_outlined,
                      color: shop['has_blue_badge'] == true ? Colors.blue : Colors.black26,
                      size: 18,
                    ),
                    onPressed: () async {
                      try {
                        final val = !(shop['has_blue_badge'] == true);
                        await Supabase.instance.client
                            .from('shops')
                            .update({'has_blue_badge': val})
                            .eq('id', shop['id']);
                        if (!context.mounted) return;
                        context.read<AdminBloc>().add(AdminFetchShops());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'Đã cấp tích xanh uy tín cho ${shop['shop_name']}! ⭐' : 'Đã thu hồi tích xanh của ${shop['shop_name']}!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi cập nhật tích xanh: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
                // Toggle ban / status
                Tooltip(
                  message: shop['status'] == 'blocked' ? 'Mở khóa nhãn hàng' : 'Khóa/Cấm nhãn hàng',
                  child: IconButton(
                    icon: Icon(
                      shop['status'] == 'blocked' ? Icons.block_flipped : Icons.check_circle_outline,
                      color: shop['status'] == 'blocked' ? Colors.red : Colors.green,
                      size: 18,
                    ),
                    onPressed: () async {
                      try {
                        final isBlocked = shop['status'] == 'blocked';
                        final nextStatus = isBlocked ? 'active' : 'blocked';
                        await Supabase.instance.client
                            .from('shops')
                            .update({'status': nextStatus})
                            .eq('id', shop['id']);
                        if (!context.mounted) return;
                        context.read<AdminBloc>().add(AdminFetchShops());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isBlocked ? 'Đã mở khóa hoạt động cho nhãn hàng!' : 'Đã khóa/cấm nhãn hàng hoạt động trên sàn! ⛔'),
                            backgroundColor: isBlocked ? Colors.green : Colors.red,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi cập nhật trạng thái hoạt động: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
                // Edit shop metadata
                Tooltip(
                  message: 'Chỉnh sửa thông tin',
                  child: IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6200EE), size: 18),
                    hoverColor: const Color(0xFF6200EE).withOpacity(0.05),
                    onPressed: () => _showShopFormModal(context, shop),
                  ),
                ),
              ],
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

    XFile? pickedLogoFile;
    Uint8List? logoBytes;
    XFile? pickedCoverFile;
    Uint8List? coverBytes;

    String? existingLogoUrl = isEdit ? shop['logo_path'] : null;
    String? existingCoverUrl = isEdit ? shop['cover_path'] : null;

    bool isUploading = false;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Cập nhật thông tin nhãn hàng 📝' : 'Tạo nhãn hàng mới 🚀',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6200EE)),
              ),
              content: Container(
                width: 500,
                constraints: const BoxConstraints(maxHeight: 520),
                child: isUploading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF6200EE)),
                            SizedBox(height: 16),
                            Text(
                              'Đang tải hình ảnh lên hệ thống...',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
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
                            const SizedBox(height: 20),

                            // Logo Selection Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ảnh đại diện (Logo) *',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        logoBytes != null
                                            ? 'Đã chọn ảnh mới 🖼️'
                                            : existingLogoUrl != null
                                                ? 'Sử dụng ảnh hiện tại'
                                                : 'Chưa chọn ảnh',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    try {
                                      final picker = ImagePicker();
                                      final file = await picker.pickImage(source: ImageSource.gallery);
                                      if (file != null) {
                                        final bytes = await file.readAsBytes();
                                        setDialogState(() {
                                          pickedLogoFile = file;
                                          logoBytes = bytes;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking logo: $e');
                                    }
                                  },
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[100],
                                      border: Border.all(color: const Color(0xFF6200EE), width: 1.5),
                                      image: logoBytes != null
                                          ? DecorationImage(image: MemoryImage(logoBytes!), fit: BoxFit.cover)
                                          : (existingLogoUrl != null && existingLogoUrl.isNotEmpty)
                                              ? DecorationImage(image: NetworkImage(existingLogoUrl), fit: BoxFit.cover)
                                              : null,
                                    ),
                                    child: logoBytes == null && (existingLogoUrl == null || existingLogoUrl.isEmpty)
                                        ? const Icon(Icons.add_a_photo_outlined, size: 24, color: Color(0xFF6200EE))
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Cover Selection
                            const Text(
                              'Ảnh bìa (Cover Banner) *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                try {
                                  final picker = ImagePicker();
                                  final file = await picker.pickImage(source: ImageSource.gallery);
                                  if (file != null) {
                                    final bytes = await file.readAsBytes();
                                    setDialogState(() {
                                      pickedCoverFile = file;
                                      coverBytes = bytes;
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('Error picking cover: $e');
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey[100],
                                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                  image: coverBytes != null
                                      ? DecorationImage(image: MemoryImage(coverBytes!), fit: BoxFit.cover)
                                      : (existingCoverUrl != null && existingCoverUrl.isNotEmpty)
                                          ? DecorationImage(image: NetworkImage(existingCoverUrl), fit: BoxFit.cover)
                                          : null,
                                ),
                                child: coverBytes == null && (existingCoverUrl == null || existingCoverUrl.isEmpty)
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey[600]),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Bấm để tải ảnh bìa lên từ máy tính',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              actions: isUploading
                  ? null
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Vui lòng điền đầy đủ các thông tin bắt buộc (*).')),
                            );
                            return;
                          }

                          // If creating a new shop, must select logo and cover!
                          if (!isEdit && (logoBytes == null || coverBytes == null)) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Vui lòng chọn đầy đủ ảnh Logo và ảnh bìa (Cover) cho thương hiệu mới.')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isUploading = true;
                          });

                          try {
                            String? finalLogoUrl = existingLogoUrl;
                            String? finalCoverUrl = existingCoverUrl;

                            // 1. Upload Logo if picked
                            if (pickedLogoFile != null && logoBytes != null) {
                              final logoFilename = pickedLogoFile!.name;
                              String logoExt = 'jpg';
                              if (logoFilename.contains('.')) {
                                final parsedLogoExt = logoFilename.split('.').last.toLowerCase();
                                if (parsedLogoExt == 'png' || parsedLogoExt == 'jpg' || parsedLogoExt == 'jpeg' || parsedLogoExt == 'gif' || parsedLogoExt == 'webp') {
                                  logoExt = parsedLogoExt;
                                }
                              }
                              final logoPath = 'shops/admin_${DateTime.now().millisecondsSinceEpoch}_logo.$logoExt';
                              await Supabase.instance.client.storage
                                  .from('avatars')
                                  .uploadBinary(logoPath, logoBytes!, fileOptions: FileOptions(contentType: 'image/$logoExt'));
                              finalLogoUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(logoPath);
                            }

                            // 2. Upload Cover if picked
                            if (pickedCoverFile != null && coverBytes != null) {
                              final coverFilename = pickedCoverFile!.name;
                              String coverExt = 'jpg';
                              if (coverFilename.contains('.')) {
                                final parsedCoverExt = coverFilename.split('.').last.toLowerCase();
                                if (parsedCoverExt == 'png' || parsedCoverExt == 'jpg' || parsedCoverExt == 'jpeg' || parsedCoverExt == 'gif' || parsedCoverExt == 'webp') {
                                  coverExt = parsedCoverExt;
                                }
                              }
                              final coverPath = 'shops/admin_${DateTime.now().millisecondsSinceEpoch}_cover.$coverExt';
                              await Supabase.instance.client.storage
                                  .from('avatars')
                                  .uploadBinary(coverPath, coverBytes!, fileOptions: FileOptions(contentType: 'image/$coverExt'));
                              finalCoverUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(coverPath);
                            }

                            if (!parentContext.mounted) return;

                            if (isEdit) {
                              parentContext.read<AdminBloc>().add(AdminUpdateShop(
                                    id: shop['id'],
                                    shopName: nameCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    logoPath: finalLogoUrl,
                                    coverPath: finalCoverUrl,
                                  ));
                            } else {
                              parentContext.read<AdminBloc>().add(AdminCreateShop(
                                    shopName: nameCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    logoPath: finalLogoUrl,
                                    coverPath: finalCoverUrl,
                                  ));
                            }

                            Navigator.pop(context);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Cập nhật nhãn hàng thành công!' : 'Tạo mới nhãn hàng thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isUploading = false;
                            });
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text('Lỗi tải hình ảnh: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6200EE),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo ngay', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
