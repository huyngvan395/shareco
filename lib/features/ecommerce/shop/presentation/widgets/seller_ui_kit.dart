import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/vietnam_regions_service.dart';

/// Danh sách đơn vị vận chuyển hỗ trợ trên ShareCo.
const List<String> kSellerCarriers = [
  'SPX Express',
  'Giao Hàng Nhanh (GHN)',
  'J&T Express',
  'Viettel Post',
  'Ninja Van',
  'GrabExpress (Hỏa tốc)',
];

const Map<String, String> kBusinessTypes = {
  'individual': 'Cá nhân',
  'household': 'Hộ kinh doanh',
  'company': 'Doanh nghiệp / Thương hiệu',
};

/// Màu chủ đạo cho khu vực người bán (đồng bộ với Shop gradient của app).
abstract class SellerPalette {
  static const primary = Color(0xFFFF4D2D);
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const border = Color(0xFFE8E8EE);
  static const textMain = Color(0xFF1F2330);
  static const textSub = Color(0xFF6B7080);
  static const field = Color(0xFFF6F7FA);
}

InputDecoration sellerInputDecoration(
  String label, {
  IconData? icon,
  String? hint,
  Widget? suffix,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    labelStyle: const TextStyle(color: SellerPalette.textSub, fontSize: 13.5),
    floatingLabelStyle: const TextStyle(
      color: SellerPalette.primary,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: SellerPalette.textSub, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: SellerPalette.field,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SellerPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SellerPalette.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

const TextStyle kSellerFieldText = TextStyle(
  color: SellerPalette.textMain,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

class SellerSectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SellerSectionCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SellerPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SellerPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: SellerPalette.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: SellerPalette.textMain,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Hỗ trợ chọn Tỉnh → Quận → Phường giống màn Địa chỉ.
class SellerRegionPicker {
  static Future<Map<String, dynamic>?> _pick(
    BuildContext context, {
    required String title,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: SellerPalette.textMain,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetcher(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: SellerPalette.primary,
                        ),
                      );
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không tải được dữ liệu, vui lòng thử lại!',
                          style: TextStyle(color: Colors.black45),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          title: Text(
                            item['name'].toString(),
                            style: const TextStyle(
                              color: SellerPalette.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<Map<String, dynamic>?> pickProvince(BuildContext context) {
    return _pick(
      context,
      title: 'Chọn Tỉnh / Thành phố',
      fetcher: () async {
        final list = await VietnamRegionsService.getProvinces();
        return list.where((e) => (e['code'] as int?) != -1 || !e['name'].toString().contains('(')).toList();
      },
    );
  }

  static Future<Map<String, dynamic>?> pickDistrict(
    BuildContext context,
    String province,
    int provinceCode,
  ) {
    return _pick(
      context,
      title: 'Chọn Quận / Huyện',
      fetcher: () => VietnamRegionsService.getDistricts(province, provinceCode),
    );
  }

  static Future<Map<String, dynamic>?> pickWard(
    BuildContext context,
    String province,
    String district,
    int districtCode,
  ) {
    return _pick(
      context,
      title: 'Chọn Phường / Xã',
      fetcher: () =>
          VietnamRegionsService.getWards(province, district, districtCode),
    );
  }
}

/// Upload ảnh người bán lên bucket `avatars` (đã mở quyền cho user đăng nhập).
class SellerMediaHelper {
  static Future<File?> pickImage(BuildContext context, {String? title}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title ?? 'Chọn ảnh',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: SellerPalette.textMain,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Chụp ảnh',
                      color: SellerPalette.primary,
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Thư viện',
                      color: const Color(0xFF3B82F6),
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  static Future<String> upload(File file, String folder) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final ext = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '$folder/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage
        .from('avatars')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    return Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

String formatVndShort(num amount) {
  final s = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
  return '$sđ';
}

