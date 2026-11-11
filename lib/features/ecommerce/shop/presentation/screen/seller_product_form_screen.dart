import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/repositories/shop_repository.dart';
import '../widgets/seller_ui_kit.dart';

/// Màn tạo / chỉnh sửa sản phẩm dành cho người bán trên mobile.
class SellerProductFormScreen extends StatefulWidget {
  final String shopId;
  final String? shopName;
  final Product? product;

  const SellerProductFormScreen({
    super.key,
    required this.shopId,
    this.shopName,
    this.product,
  });

  @override
  State<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _VariantDraft {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController stock;
  final TextEditingController sku;

  _VariantDraft({
    String name = '',
    String price = '',
    String stock = '',
    String sku = '',
  })  : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        stock = TextEditingController(text: stock),
        sku = TextEditingController(text: sku);

  void dispose() {
    name.dispose();
    price.dispose();
    stock.dispose();
    sku.dispose();
  }
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();

  final List<_VariantDraft> _variants = [];
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  String _status = 'active';
  File? _coverFile;
  bool _loadingCats = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;
  ShopRepository get _repo => sl<ShopRepository>();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _titleCtrl.text = p.title;
      _brandCtrl.text = p.brand ?? '';
      _descCtrl.text = p.description ?? '';
      _priceCtrl.text = p.priceMin.toStringAsFixed(0);
      _originalPriceCtrl.text = p.originalPrice?.toStringAsFixed(0) ?? '';
      _stockCtrl.text = p.stockTotal.toString();
      _coverUrlCtrl.text = p.coverPath ?? '';
      _categoryId = p.categoryId;
      _status = p.status == 'inactive' ? 'inactive' : 'active';
      for (final v in p.variants) {
        final name = v.variantName ?? '';
        if (name.isEmpty || name == 'Tiêu chuẩn') continue;
        _variants.add(_VariantDraft(
          name: name,
          price: v.price.toStringAsFixed(0),
          stock: v.stockQty.toString(),
          sku: v.sku ?? '',
        ));
      }
    } else {
      _brandCtrl.text = widget.shopName ?? '';
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final res = await _repo.getProductCategories();
    if (!mounted) return;
    res.fold(
      (_) {},
      (list) => _categories = list,
    );
    setState(() {
      _loadingCats = false;
      if (_categoryId == null && _categories.isNotEmpty) {
        _categoryId = _categories.first['id'] as String?;
      }
      if (_categoryId != null &&
          !_categories.any((c) => c['id'] == _categoryId)) {
        _categoryId = _categories.isNotEmpty
            ? _categories.first['id'] as String?
            : null;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _brandCtrl,
      _descCtrl,
      _priceCtrl,
      _originalPriceCtrl,
      _stockCtrl,
      _coverUrlCtrl,
    ]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _createCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Tạo danh mục mới',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: SellerPalette.textMain,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: kSellerFieldText,
          decoration: sellerInputDecoration(
            'Tên danh mục',
            hint: 'VD: Chăm sóc da, Phụ kiện...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    final res = await _repo.createProductCategory(name);
    if (!mounted) return;
    res.fold(
      (f) => _toast('Không tạo được danh mục: ${f.message}', error: true),
      (cat) => setState(() {
        _categories = [..._categories, cat];
        _categoryId = cat['id'] as String?;
      }),
    );
  }

  Future<void> _pickCover() async {
    final file = await SellerMediaHelper.pickImage(
      context,
      title: 'Ảnh bìa sản phẩm',
    );
    if (file != null && mounted) setState(() => _coverFile = file);
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      return _toast('Vui lòng chọn danh mục sản phẩm', error: true);
    }
    if (_coverFile == null && _coverUrlCtrl.text.trim().isEmpty) {
      return _toast('Vui lòng thêm ảnh bìa sản phẩm', error: true);
    }

    setState(() => _saving = true);
    try {
      var cover = _coverUrlCtrl.text.trim();
      if (_coverFile != null) {
        cover = await SellerMediaHelper.upload(
          _coverFile!,
          'products/${widget.shopId}',
        );
      }

      final price = double.parse(_priceCtrl.text.trim());
      final original = double.tryParse(_originalPriceCtrl.text.trim());
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

      final variants = _variants
          .where((v) => v.name.text.trim().isNotEmpty)
          .map((v) => {
                'variant_name': v.name.text.trim(),
                'price': double.tryParse(v.price.text.trim()) ?? price,
                'stock_qty': int.tryParse(v.stock.text.trim()) ?? 0,
                'sku': v.sku.text.trim(),
              })
          .toList();

      final res = await _repo.upsertSellerProduct(
        productId: widget.product?.id,
        shopId: widget.shopId,
        categoryId: _categoryId!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        price: price,
        originalPrice:
            (original != null && original > price) ? original : null,
        stock: stock,
        status: _status,
        coverPath: cover,
        variants: variants,
      );

      if (!mounted) return;
      res.fold(
        (f) => _toast('Lưu sản phẩm thất bại: ${f.message}', error: true),
        (_) {
          _toast(_isEdit ? 'Đã cập nhật sản phẩm' : 'Đã đăng sản phẩm mới 🎉');
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      if (mounted) _toast('Lỗi: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = StorageImage.publicUrl(_coverUrlCtrl.text.trim());

    return Scaffold(
      backgroundColor: SellerPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SellerPalette.textMain,
        elevation: 0,
        title: Text(
          _isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            SellerSectionCard(
              title: 'Ảnh sản phẩm',
              icon: Icons.image_outlined,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickCover,
                    child: AspectRatio(
                      aspectRatio: 1.6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: SellerPalette.field,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: SellerPalette.border),
                          image: _coverFile != null
                              ? DecorationImage(
                                  image: FileImage(_coverFile!),
                                  fit: BoxFit.cover,
                                )
                              : (coverUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(coverUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                        child: (_coverFile == null && coverUrl == null)
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 36, color: SellerPalette.primary),
                                  SizedBox(height: 6),
                                  Text(
                                    'Chụp / chọn ảnh bìa sản phẩm *',
                                    style: TextStyle(
                                      color: SellerPalette.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: const EdgeInsets.all(10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Đổi ảnh',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _coverUrlCtrl,
                    style: kSellerFieldText,
                    onChanged: (_) => setState(() {}),
                    decoration: sellerInputDecoration(
                      'Hoặc dán link ảnh (URL)',
                      icon: Icons.link_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SellerSectionCard(
              title: 'Thông tin cơ bản',
              icon: Icons.inventory_2_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    style: kSellerFieldText,
                    maxLength: 120,
                    decoration: sellerInputDecoration('Tên sản phẩm *'),
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'Tên sản phẩm tối thiểu 5 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _loadingCats
                            ? const LinearProgressIndicator(
                                color: SellerPalette.primary,
                              )
                            : DropdownButtonFormField<String>(
                                value: _categoryId,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style: kSellerFieldText,
                                decoration:
                                    sellerInputDecoration('Danh mục *'),
                                items: _categories
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c['id'] as String,
                                          child: Text(
                                            c['name']?.toString() ?? '',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _categoryId = v),
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Tạo danh mục',
                        onPressed: _createCategory,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              SellerPalette.primary.withValues(alpha: 0.1),
                          foregroundColor: SellerPalette.primary,
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandCtrl,
                    style: kSellerFieldText,
                    decoration: sellerInputDecoration(
                      'Thương hiệu',
                      icon: Icons.sell_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    style: kSellerFieldText,
                    decoration: sellerInputDecoration(
                      'Mô tả sản phẩm',
                      hint: 'Công dụng, chất liệu, kích thước, hướng dẫn sử dụng...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SellerSectionCard(
              title: 'Giá bán & Tồn kho',
              icon: Icons.payments_outlined,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          style: kSellerFieldText,
                          decoration: sellerInputDecoration(
                            'Giá bán *',
                            prefixText: '₫ ',
                          ),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            return (n == null || n <= 0)
                                ? 'Giá không hợp lệ'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _originalPriceCtrl,
                          keyboardType: TextInputType.number,
                          style: kSellerFieldText,
                          decoration: sellerInputDecoration(
                            'Giá gốc (gạch)',
                            prefixText: '₫ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    style: kSellerFieldText,
                    decoration: sellerInputDecoration(
                      _variants.isEmpty
                          ? 'Số lượng tồn kho *'
                          : 'Tồn kho (tự tính theo phân loại)',
                      icon: Icons.warehouse_outlined,
                    ),
                    validator: (v) {
                      if (_variants.isNotEmpty) return null;
                      final n = int.tryParse((v ?? '').trim());
                      return (n == null || n < 0) ? 'Tồn kho không hợp lệ' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _status == 'active',
                    onChanged: (v) =>
                        setState(() => _status = v ? 'active' : 'inactive'),
                    activeColor: SellerPalette.primary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hiển thị & mở bán ngay',
                      style: TextStyle(
                        color: SellerPalette.textMain,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      _status == 'active'
                          ? 'Khách hàng có thể tìm thấy và đặt mua'
                          : 'Sản phẩm đang ẩn khỏi gian hàng',
                      style: const TextStyle(
                        color: SellerPalette.textSub,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SellerSectionCard(
              title: 'Phân loại hàng (${_variants.length})',
              icon: Icons.tune_rounded,
              trailing: TextButton.icon(
                onPressed: () => setState(() => _variants.add(_VariantDraft(
                      price: _priceCtrl.text,
                      stock: '10',
                    ))),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm'),
                style: TextButton.styleFrom(
                  foregroundColor: SellerPalette.primary,
                ),
              ),
              child: _variants.isEmpty
                  ? const Text(
                      'Chưa có phân loại — hệ thống sẽ dùng phân loại "Tiêu chuẩn". Thêm phân loại nếu sản phẩm có màu sắc, size, dung tích...',
                      style: TextStyle(
                        color: SellerPalette.textSub,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    )
                  : Column(
                      children: List.generate(_variants.length, (i) {
                        final v = _variants[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SellerPalette.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: v.name,
                                      style: kSellerFieldText,
                                      decoration: sellerInputDecoration(
                                        'Tên phân loại ${i + 1}',
                                        hint: 'VD: Đỏ - Size M',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    onPressed: () => setState(() {
                                      _variants.removeAt(i).dispose();
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: v.price,
                                      keyboardType: TextInputType.number,
                                      style: kSellerFieldText,
                                      decoration:
                                          sellerInputDecoration('Giá'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: v.stock,
                                      keyboardType: TextInputType.number,
                                      style: kSellerFieldText,
                                      decoration:
                                          sellerInputDecoration('Tồn kho'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: v.sku,
                                      style: kSellerFieldText,
                                      decoration:
                                          sellerInputDecoration('SKU'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: SellerPalette.border)),
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isEdit ? 'Lưu thay đổi' : 'Đăng bán sản phẩm',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

