import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../widgets/seller_ui_kit.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  int _provinceCode = -1;
  int _districtCode = -1;
  String _businessType = 'individual';
  String _carrier = kSellerCarriers.first;
  bool _agreed = false;

  File? _logoFile;
  File? _coverFile;

  bool _isLoading = false;
  bool _checking = true;
  bool _showCreateForm = false;
  List<Shop> _myShops = const [];

  ShopRepository get _repo => sl<ShopRepository>();

  @override
  void initState() {
    super.initState();
    _loadMyShops();
  }

  Future<void> _loadMyShops() async {
    setState(() => _checking = true);
    final result = await _repo.getMyShops();
    if (!mounted) return;
    result.fold(
      (failure) => debugPrint('Load my shops failed: ${failure.message}'),
      (shops) => _myShops = shops,
    );
    setState(() {
      _checking = false;
      _showCreateForm = _myShops.isEmpty;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _slugCtrl,
      _descCtrl,
      _phoneCtrl,
      _emailCtrl,
      _provinceCtrl,
      _districtCtrl,
      _wardCtrl,
      _addressCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNameChanged(String val) {
    var clean = val.toLowerCase();
    const map = <String, String>{
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'd': 'đ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
    };
    map.forEach((latin, accented) {
      for (final ch in accented.split('')) {
        clean = clean.replaceAll(ch, latin);
      }
    });
    _slugCtrl.text = clean
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _pickProvince() async {
    final res = await SellerRegionPicker.pickProvince(context);
    if (res == null) return;
    setState(() {
      _provinceCtrl.text = res['name'].toString();
      _provinceCode = (res['code'] as int?) ?? -1;
      _districtCtrl.clear();
      _wardCtrl.clear();
      _districtCode = -1;
    });
    if (mounted) _pickDistrict();
  }

  Future<void> _pickDistrict() async {
    if (_provinceCtrl.text.isEmpty) return _pickProvince();
    final res = await SellerRegionPicker.pickDistrict(
      context,
      _provinceCtrl.text,
      _provinceCode,
    );
    if (res == null) return;
    setState(() {
      _districtCtrl.text = res['name'].toString();
      _districtCode = (res['code'] as int?) ?? -1;
      _wardCtrl.clear();
    });
    if (mounted) _pickWard();
  }

  Future<void> _pickWard() async {
    if (_districtCtrl.text.isEmpty) return _pickDistrict();
    final res = await SellerRegionPicker.pickWard(
      context,
      _provinceCtrl.text,
      _districtCtrl.text,
      _districtCode,
    );
    if (res == null) return;
    setState(() => _wardCtrl.text = res['name'].toString());
  }

  Future<void> _pickImage(bool isLogo) async {
    final file = await SellerMediaHelper.pickImage(
      context,
      title: isLogo ? 'Ảnh đại diện (Logo) shop' : 'Ảnh bìa shop',
    );
    if (file == null || !mounted) return;
    setState(() {
      if (isLogo) {
        _logoFile = file;
      } else {
        _coverFile = file;
      }
    });
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_logoFile == null) {
      return _toast('Vui lòng chọn ảnh đại diện (Logo) cho shop.', error: true);
    }
    if (!_agreed) {
      return _toast(
        'Vui lòng đồng ý với Chính sách người bán ShareCo.',
        error: true,
      );
    }

    setState(() => _isLoading = true);
    try {
      final logoUrl = await SellerMediaHelper.upload(_logoFile!, 'shops');
      String? coverUrl;
      if (_coverFile != null) {
        coverUrl = await SellerMediaHelper.upload(_coverFile!, 'shops');
      }

      final result = await _repo.registerShop(
        shopName: _nameCtrl.text.trim(),
        shopSlug: _slugCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        contactPhone: _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
        businessType: _businessType,
        pickupProvince: _provinceCtrl.text.trim(),
        pickupDistrict: _districtCtrl.text.trim(),
        pickupWard: _wardCtrl.text.trim(),
        pickupAddress: _addressCtrl.text.trim(),
        defaultCarrier: _carrier,
      );

      if (!mounted) return;
      result.fold(
        (failure) => _toast('Đăng ký thất bại: ${failure.message}', error: true),
        (shop) => _showSuccess(shop),
      );
    } catch (e) {
      if (mounted) _toast('Đăng ký thất bại: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(Shop shop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 60),
            SizedBox(height: 12),
            Text(
              'Mở shop thành công! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                color: SellerPalette.textMain,
              ),
            ),
          ],
        ),
        content: Text(
          '"${shop.shopName}" đã sẵn sàng kinh doanh. Vào Kênh Người Bán để đăng sản phẩm, '
          'xử lý đơn hàng và cập nhật vận chuyển ngay trên điện thoại.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SellerPalette.textSub, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushReplacement(
                '/seller-center',
                extra: {'shopId': shop.id},
              );
            },
            icon: const Icon(Icons.dashboard_customize_rounded),
            label: const Text(
              'Mở Kênh Người Bán',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SellerPalette.textMain,
        elevation: 0,
        title: Text(
          _showCreateForm ? 'Đăng ký bán hàng' : 'Cửa hàng của tôi',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_showCreateForm && _myShops.isNotEmpty) {
              setState(() => _showCreateForm = false);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: _checking
          ? const Center(
              child: CircularProgressIndicator(color: SellerPalette.primary),
            )
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: SellerPalette.primary),
                      SizedBox(height: 14),
                      Text(
                        'Đang khởi tạo gian hàng của bạn...',
                        style: TextStyle(color: SellerPalette.textSub),
                      ),
                    ],
                  ),
                )
              : _showCreateForm
                  ? _buildForm()
                  : _buildMyShops(),
    );
  }

  Widget _buildMyShops() {
    return RefreshIndicator(
      onRefresh: _loadMyShops,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppShopGradient.gradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn đang sở hữu ${_myShops.length} gian hàng trên ShareCo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._myShops.map(
            (shop) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MyShopCard(shop: shop),
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            icon: const Icon(Icons.add_business_rounded),
            label: const Text(
              'Đăng ký thêm cửa hàng mới',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: SellerPalette.primary,
              side: const BorderSide(color: SellerPalette.primary),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppShopGradient.gradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trở thành Người bán ShareCo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Bán hàng qua video, livestream & quản lý đơn ngay trên điện thoại. Miễn phí mở shop!',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Hình ảnh gian hàng',
            icon: Icons.photo_camera_back_outlined,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: SellerPalette.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SellerPalette.border),
                      image: _coverFile != null
                          ? DecorationImage(
                              image: FileImage(_coverFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: SellerPalette.textSub, size: 32),
                              SizedBox(height: 6),
                              Text(
                                'Ảnh bìa (không bắt buộc)',
                                style: TextStyle(color: SellerPalette.textSub),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(true),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            SellerPalette.primary.withValues(alpha: 0.1),
                        backgroundImage:
                            _logoFile != null ? FileImage(_logoFile!) : null,
                        child: _logoFile == null
                            ? const Icon(Icons.add_a_photo_outlined,
                                color: SellerPalette.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Logo shop * — ảnh vuông, rõ nét giúp khách nhận diện thương hiệu tốt hơn.',
                        style: TextStyle(
                          color: SellerPalette.textSub,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Thông tin cửa hàng',
            icon: Icons.storefront_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  onChanged: _onNameChanged,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Tên shop *',
                    icon: Icons.store_mall_directory_outlined,
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Tên shop tối thiểu 3 ký tự'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugCtrl,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Đường dẫn shop (tự động)',
                    icon: Icons.link_rounded,
                    prefixText: 'shareco/',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Mô tả shop *',
                    hint: 'Sản phẩm chính, cam kết chính hãng, chính sách đổi trả...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập mô tả'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  dropdownColor: Colors.white,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Loại hình kinh doanh',
                    icon: Icons.badge_outlined,
                  ),
                  items: kBusinessTypes.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _businessType = v ?? 'individual'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Số điện thoại kho / CSKH *',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 9 ? 'Số điện thoại không hợp lệ' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Email liên hệ',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Địa chỉ kho lấy hàng',
            icon: Icons.warehouse_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _provinceCtrl,
                  readOnly: true,
                  onTap: _pickProvince,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Tỉnh / Thành phố *',
                    icon: Icons.map_outlined,
                    suffix: const Icon(Icons.arrow_drop_down,
                        color: SellerPalette.textSub),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _districtCtrl,
                        readOnly: true,
                        onTap: _pickDistrict,
                        style: kSellerFieldText,
                        decoration: sellerInputDecoration('Quận / Huyện *'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Bắt buộc' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _wardCtrl,
                        readOnly: true,
                        onTap: _pickWard,
                        style: kSellerFieldText,
                        decoration: sellerInputDecoration('Phường / Xã *'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Bắt buộc' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Số nhà, tên đường *',
                    icon: Icons.home_work_outlined,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập địa chỉ cụ thể'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _carrier,
                  dropdownColor: Colors.white,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Đơn vị vận chuyển mặc định',
                    icon: Icons.local_shipping_outlined,
                  ),
                  items: kSellerCarriers
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _carrier = v ?? kSellerCarriers.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            activeColor: SellerPalette.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Tôi đồng ý với Chính sách người bán, cam kết hàng chính hãng & giao đúng hạn.',
              style: TextStyle(
                color: SellerPalette.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Mở shop ngay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient đồng bộ với `AppColors.shopGradient`.
abstract class AppShopGradient {
  static const gradient = LinearGradient(
    colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _MyShopCard extends StatelessWidget {
  final Shop shop;

  const _MyShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final logo = StorageImage.publicUrl(shop.logoPath, bucket: 'avatars');
    final Color statusColor;
    final String statusLabel;

    if (shop.isPending) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Chờ phê duyệt ⏳';
    } else if (shop.isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Bị từ chối ❌';
    } else if (shop.isBlocked) {
      statusColor = const Color(0xFF991B1B);
      statusLabel = 'Tạm khóa 🚫';
    } else {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Đang bán ✅';
    }

    return SellerSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: SellerPalette.field,
                backgroundImage: logo != null ? NetworkImage(logo) : null,
                child: logo == null
                    ? const Icon(Icons.storefront, color: SellerPalette.textSub)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: SellerPalette.textMain,
                            ),
                          ),
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF20A4F3), size: 17),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📍 Kho: ${shop.pickupHubLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SellerPalette.textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (shop.isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hồ sơ đăng ký đang được Ban Quản Trị ShareCo xét duyệt. Khi được duyệt, bạn sẽ có thể đăng bán sản phẩm & mở Live.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (shop.isRejected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${shop.rejectionReason ?? 'Chưa đáp ứng tiêu chuẩn mở gian hàng'}',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('${shop.productCount}', 'Sản phẩm'),
              _stat('${shop.followerCount}', 'Theo dõi'),
              _stat(shop.ratingAvg.toStringAsFixed(1), 'Đánh giá'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/shop/${shop.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SellerPalette.textMain,
                    side: const BorderSide(color: SellerPalette.border),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Xem gian hàng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: shop.isActive
                      ? () => context.push(
                            '/seller-center',
                            extra: {'shopId': shop.id},
                          )
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(shop.isPending
                                  ? 'Gian hàng đang chờ duyệt, vui lòng đợi Ban Quản Trị phê duyệt.'
                                  : 'Gian hàng hiện không thể mở kênh người bán.'),
                            ),
                          );
                        },
                  icon: Icon(
                    shop.isActive
                        ? Icons.dashboard_customize_rounded
                        : Icons.lock_clock_rounded,
                    size: 18,
                  ),
                  label: Text(
                    shop.isActive ? 'Mở Kênh Người Bán' : 'Chờ Phê Duyệt',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: shop.isActive
                        ? SellerPalette.primary
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: SellerPalette.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: SellerPalette.textSub, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
