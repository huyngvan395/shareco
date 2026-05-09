import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_layout.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_event.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_state.dart';

class AdminProductFormScreen extends StatefulWidget {
  final String? productId;

  const AdminProductFormScreen({super.key, this.productId});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();

  String? _selectedShopId;
  String? _selectedCategoryId;

  List<Map<String, dynamic>> _shopsList = [];
  List<Map<String, dynamic>> _categoriesList = [];
  bool _isLoadingDropdowns = true;
  bool _isEditMode = false;

  // Custom variants list [{name: "Xanh - S", price: 150000, stock: 20}]
  final List<Map<String, dynamic>> _variants = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productId != null;
    _loadMetadata();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _originalPriceCtrl.dispose();
    _stockCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch shops
      final shopsData = await supabase.from('shops').select('id, shop_name').order('shop_name');
      // 2. Fetch categories
      final catsData = await supabase.from('product_categories').select('id, name').order('name');

      setState(() {
        _shopsList = List<Map<String, dynamic>>.from(shopsData);
        _categoriesList = List<Map<String, dynamic>>.from(catsData);
        _isLoadingDropdowns = false;
      });

      if (_isEditMode) {
        _loadProductForEdit();
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu metadata: $e');
    }
  }

  Future<void> _loadProductForEdit() async {
    try {
      final supabase = Supabase.instance.client;
      final p = await supabase.from('products').select('''
        *,
        product_variants (*)
      ''').eq('id', widget.productId!).single();

      setState(() {
        _titleCtrl.text = p['title'] ?? '';
        _descCtrl.text = p['description'] ?? '';
        _priceCtrl.text = (p['price_min'] as num?)?.toStringAsFixed(0) ?? '0';
        _originalPriceCtrl.text = p['original_price'] != null ? (p['original_price'] as num).toStringAsFixed(0) : '';
        _stockCtrl.text = (p['stock_total'] as num?)?.toString() ?? '0';
        _coverCtrl.text = p['cover_path'] ?? '';
        _selectedShopId = p['shop_id'];
        _selectedCategoryId = p['category_id'];

        // Load existing variants if any
        final vars = List<Map<String, dynamic>>.from(p['product_variants'] ?? []);
        _variants.clear();
        for (final v in vars) {
          if (v['variant_name'] != 'Tiêu chuẩn') {
            _variants.add({
              'name': v['variant_name'] ?? '',
              'price': (v['price'] as num?)?.toDouble() ?? 0.0,
              'stock': v['stock_qty'] ?? 0,
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Lỗi tải thông tin sản phẩm sửa: $e');
    }
  }

  void _addNewVariant() {
    setState(() {
      _variants.add({
        'name': '',
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
      });
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc(),
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
            title: _isEditMode ? 'Chỉnh sửa Sản phẩm ✍️' : 'Đăng Sản phẩm Mới lên sàn 🚀',
            child: _isLoadingDropdowns
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back Button
                          OutlinedButton.icon(
                            onPressed: () => context.go('/products'),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Quay lại danh sách', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Basic Information Form
                              Expanded(
                                flex: 3,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Thông tin chung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        const SizedBox(height: 20),
                                        // Product Title
                                        TextFormField(
                                          controller: _titleCtrl,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            labelText: 'Tên sản phẩm *',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
                                        ),
                                        const SizedBox(height: 20),
                                        // Brand & Category Dropdowns
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String?>(
                                                value: _selectedShopId,
                                                decoration: const InputDecoration(
                                                  labelText: 'Nhãn hàng sở hữu *',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: _shopsList.map((shop) {
                                                  return DropdownMenuItem<String?>(
                                                    value: shop['id'],
                                                    child: Text(shop['shop_name'] ?? 'Shop'),
                                                  );
                                                }).toList(),
                                                onChanged: _isEditMode
                                                    ? null // Lock shop change during edit
                                                    : (val) => setState(() => _selectedShopId = val),
                                                validator: (v) => v == null ? 'Vui lòng chọn nhãn hàng sở hữu' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: DropdownButtonFormField<String?>(
                                                value: _selectedCategoryId,
                                                decoration: const InputDecoration(
                                                  labelText: 'Danh mục sản phẩm *',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: _categoriesList.map((cat) {
                                                  return DropdownMenuItem<String?>(
                                                    value: cat['id'],
                                                    child: Text(cat['name'] ?? 'Danh mục'),
                                                  );
                                                }).toList(),
                                                onChanged: _isEditMode
                                                    ? null
                                                    : (val) => setState(() => _selectedCategoryId = val),
                                                validator: (v) => v == null ? 'Vui lòng chọn danh mục sản phẩm' : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        // Price, Original Price & Stock
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _priceCtrl,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                                decoration: const InputDecoration(
                                                  labelText: 'Giá bán thực tế (VND) *',
                                                  border: OutlineInputBorder(),
                                                  prefixText: 'đ ',
                                                ),
                                                validator: (v) => v == null || double.tryParse(v) == null ? 'Nhập giá bán hợp lệ' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _originalPriceCtrl,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                                decoration: const InputDecoration(
                                                  labelText: 'Giá gốc ban đầu (Không bắt buộc)',
                                                  border: OutlineInputBorder(),
                                                  prefixText: 'đ ',
                                                  helperText: 'Để trống nếu không khuyến mãi',
                                                ),
                                                validator: (v) {
                                                  if (v != null && v.trim().isNotEmpty) {
                                                    if (double.tryParse(v) == null) return 'Nhập giá gốc hợp lệ';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _stockCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Tổng số lượng kho *',
                                                  border: OutlineInputBorder(),
                                                  helperText: 'Số lượng hàng hiện tại',
                                                ),
                                                validator: (v) => v == null || int.tryParse(v) == null ? 'Nhập tồn kho hợp lệ' : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        // Cover Image URL
                                        TextFormField(
                                          controller: _coverCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Đường dẫn ảnh bìa đại diện (Cover Image URL)',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.image),
                                            hintText: 'https://images.unsplash.com/...',
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        // Description
                                        TextFormField(
                                          controller: _descCtrl,
                                          maxLines: 6,
                                          decoration: const InputDecoration(
                                            labelText: 'Mô tả chi tiết sản phẩm',
                                            border: OutlineInputBorder(),
                                            alignLabelWithHint: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right Column: Dynamic Variants Selector
                              Expanded(
                                flex: 2,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Phân loại & Mẫu mã (Variants)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                            ElevatedButton.icon(
                                              onPressed: _addNewVariant,
                                              icon: const Icon(Icons.add, size: 14),
                                              label: const Text('Thêm loại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF6200EE).withOpacity(0.1),
                                                foregroundColor: const Color(0xFF6200EE),
                                                elevation: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Nếu có phân loại (Ví dụ: Màu sắc, Size), hãy điền chi tiết vào đây. Nếu không, hệ thống sẽ tự thiết lập mẫu mặc định.',
                                          style: TextStyle(fontSize: 12, color: Colors.black38),
                                        ),
                                        const SizedBox(height: 20),
                                        _variants.isEmpty
                                            ? Container(
                                                padding: const EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Text('Đang áp dụng phân loại tiêu chuẩn (1 phân loại duy nhất)', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
                                              )
                                            : ListView.separated(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: _variants.length,
                                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                itemBuilder: (context, index) {
                                                  final v = _variants[index];
                                                  return Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 3,
                                                        child: TextFormField(
                                                          initialValue: v['name'],
                                                          decoration: const InputDecoration(labelText: 'Tên (Ví dụ: Xanh - 128GB)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                                          onChanged: (val) => v['name'] = val,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        flex: 2,
                                                        child: TextFormField(
                                                          initialValue: v['price'].toString(),
                                                          keyboardType: TextInputType.number,
                                                          decoration: const InputDecoration(labelText: 'Giá', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                                          onChanged: (val) => v['price'] = double.tryParse(val) ?? 0.0,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        flex: 2,
                                                        child: TextFormField(
                                                          initialValue: v['stock'].toString(),
                                                          keyboardType: TextInputType.number,
                                                          decoration: const InputDecoration(labelText: 'Tồn', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                                          onChanged: (val) => v['stock'] = int.tryParse(val) ?? 0,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                        onPressed: () => _removeVariant(index),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Form Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => context.go('/products'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) return;

                                  // Validate brand-owners & categories
                                  if (_selectedShopId == null || _selectedCategoryId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Vui lòng điền đủ Nhãn hàng và Danh mục!'), backgroundColor: Colors.red),
                                    );
                                    return;
                                  }

                                  final title = _titleCtrl.text.trim();
                                  final desc = _descCtrl.text.trim();
                                  final price = double.parse(_priceCtrl.text.trim());
                                  final originalPriceStr = _originalPriceCtrl.text.trim();
                                  final double? originalPrice = originalPriceStr.isNotEmpty ? double.tryParse(originalPriceStr) : null;
                                  final stock = int.parse(_stockCtrl.text.trim());
                                  final cover = _coverCtrl.text.trim().isNotEmpty ? _coverCtrl.text.trim() : null;

                                  final bloc = context.read<AdminBloc>();

                                  if (_isEditMode) {
                                    bloc.add(AdminUpdateProduct(
                                      productId: widget.productId!,
                                      title: title,
                                      description: desc,
                                      price: price,
                                      originalPrice: originalPrice,
                                      stock: stock,
                                      coverPath: cover,
                                    ));
                                  } else {
                                    bloc.add(AdminCreateProduct(
                                      shopId: _selectedShopId!,
                                      categoryId: _selectedCategoryId!,
                                      title: title,
                                      description: desc,
                                      price: price,
                                      originalPrice: originalPrice,
                                      stock: stock,
                                      coverPath: cover,
                                      variants: _variants,
                                    ));
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_isEditMode ? 'Cập nhật sản phẩm thành công!' : 'Đăng sản phẩm thành công!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  context.go('/products');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6200EE),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(_isEditMode ? 'Lưu thay đổi sản phẩm' : 'Đăng sản phẩm lên sàn', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
