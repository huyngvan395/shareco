import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_layout.dart';
import 'package:shareco/features/ecommerce/admin/presentation/screen/admin_login_screen.dart';
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

  XFile? _pickedCoverFile;
  Uint8List? _coverBytes;
  bool _isSaving = false;

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

  String _generateSlug(String text) {
    var str = text.toLowerCase().trim();
    const vietnamese = 'aáàảãạăắằẳẵặâấầẩẫậeéèẻẽẹêếềểễệiíìỉĩịoóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữựyýỳỷỹỵdđ';
    const english =    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiiioooooooooooooooooouuuuuuuuuuuuyyyyyydd';
    for (int i = 0; i < vietnamese.length; i++) {
      str = str.replaceAll(vietnamese[i], english[i]);
    }
    str = str.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    str = str.replaceAll(RegExp(r'\s+'), '-');
    str = str.replaceAll(RegExp(r'-+'), '-');
    return str;
  }

  Future<void> _showCreateCategoryDialog() async {
    final catNameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tạo danh mục mới 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: catNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục *',
                    hintText: 'Ví dụ: Mỹ phẩm, Làm đẹp...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên danh mục' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setDialogState(() {
                            isAdding = true;
                          });

                          try {
                            final name = catNameCtrl.text.trim();
                            final slug = _generateSlug(name);

                            final response = await Supabase.instance.client
                                .from('product_categories')
                                .insert({
                                  'name': name,
                                  'slug': slug,
                                })
                                .select('id, name')
                                .single();

                            final newCat = Map<String, dynamic>.from(response);
                            
                            setState(() {
                              _categoriesList.add(newCat);
                              _selectedCategoryId = newCat['id'];
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã tạo danh mục "$name" thành công!'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isAdding = false;
                            });
                            debugPrint('Error creating category: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi khi tạo danh mục: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6200EE),
                    foregroundColor: Colors.white,
                  ),
                  child: isAdding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
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
        if (AdminSession.loggedInRole == 'shop') {
          _selectedShopId = AdminSession.loggedInShopId;
        }
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
                                            if (AdminSession.loggedInRole == 'shop')
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.black12),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Nhãn hàng sở hữu', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        AdminSession.loggedInShopName ?? 'Gian hàng của tôi',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            else
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
                                                  onChanged: (val) => setState(() => _selectedShopId = val),
                                                  validator: (v) => v == null ? 'Vui lòng chọn nhãn hàng sở hữu' : null,
                                                ),
                                              ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
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
                                                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                                                      validator: (v) => v == null ? 'Vui lòng chọn danh mục sản phẩm' : null,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    height: 56,
                                                    width: 56,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6200EE).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.black12),
                                                    ),
                                                    child: IconButton(
                                                      icon: const Icon(Icons.add, color: Color(0xFF6200EE)),
                                                      tooltip: 'Tạo danh mục mới',
                                                      onPressed: _showCreateCategoryDialog,
                                                    ),
                                                  ),
                                                ],
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
                                        const Text(
                                          'Ảnh bìa đại diện sản phẩm *',
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
                                                setState(() {
                                                  _pickedCoverFile = file;
                                                  _coverBytes = bytes;
                                                });
                                              }
                                            } catch (e) {
                                              debugPrint('Error picking cover: $e');
                                            }
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            height: 160,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: Colors.grey[50],
                                              border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                              image: _coverBytes != null
                                                  ? DecorationImage(image: MemoryImage(_coverBytes!), fit: BoxFit.cover)
                                                  : (_coverCtrl.text.isNotEmpty)
                                                      ? DecorationImage(image: NetworkImage(_coverCtrl.text), fit: BoxFit.cover)
                                                      : null,
                                            ),
                                            child: _coverBytes == null && _coverCtrl.text.isEmpty
                                                ? Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.cloud_upload_outlined, size: 38, color: Color(0xFF6200EE)),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Bấm để tải lên ảnh sản phẩm từ máy tính',
                                                        style: TextStyle(color: Color(0xFF6200EE), fontSize: 13, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Hỗ trợ JPG, PNG, WEBP',
                                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                                      ),
                                                    ],
                                                  )
                                                : Align(
                                                    alignment: Alignment.bottomRight,
                                                    child: Container(
                                                      margin: const EdgeInsets.all(12),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black87,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.edit, color: Colors.white, size: 12),
                                                          SizedBox(width: 4),
                                                          Text('Thay đổi ảnh', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
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
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        if (!_formKey.currentState!.validate()) return;

                                        // Validate brand-owners & categories
                                        if (_selectedShopId == null || _selectedCategoryId == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Vui lòng điền đủ Nhãn hàng và Danh mục!'), backgroundColor: Colors.red),
                                          );
                                          return;
                                        }

                                        // Ensure an image is selected when creating a new product
                                        if (!_isEditMode && _pickedCoverFile == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Vui lòng chọn ảnh bìa cho sản phẩm!'), backgroundColor: Colors.red),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          _isSaving = true;
                                        });

                                        // Show custom loading overlay dialog
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (dialogContext) => const PopScope(
                                            canPop: false,
                                            child: AlertDialog(
                                              content: Row(
                                                children: [
                                                  CircularProgressIndicator(color: Color(0xFF6200EE)),
                                                  SizedBox(width: 20),
                                                  Expanded(
                                                    child: Text(
                                                      'Đang xử lý tải hình ảnh và lưu sản phẩm lên hệ thống...',
                                                      style: TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );

                                        try {
                                          String? finalCoverUrl = _coverCtrl.text.trim().isNotEmpty ? _coverCtrl.text.trim() : null;

                                          // Upload if there's a new picked cover
                                          if (_pickedCoverFile != null && _coverBytes != null) {
                                            final filename = _pickedCoverFile!.name;
                                            String ext = 'jpg';
                                            if (filename.contains('.')) {
                                              final parsedExt = filename.split('.').last.toLowerCase();
                                              if (parsedExt == 'png' || parsedExt == 'jpg' || parsedExt == 'jpeg' || parsedExt == 'gif' || parsedExt == 'webp') {
                                                ext = parsedExt;
                                              }
                                            }
                                            final path = 'products/prod_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                            await Supabase.instance.client.storage
                                                .from('avatars')
                                                .uploadBinary(path, _coverBytes!, fileOptions: FileOptions(contentType: 'image/$ext'));
                                            finalCoverUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
                                          }

                                          if (!context.mounted) return;

                                          final title = _titleCtrl.text.trim();
                                          final desc = _descCtrl.text.trim();
                                          final price = double.parse(_priceCtrl.text.trim());
                                          final originalPriceStr = _originalPriceCtrl.text.trim();
                                          final double? originalPrice = originalPriceStr.isNotEmpty ? double.tryParse(originalPriceStr) : null;
                                          final stock = int.parse(_stockCtrl.text.trim());

                                          final bloc = context.read<AdminBloc>();

                                          if (_isEditMode) {
                                            bloc.add(AdminUpdateProduct(
                                              productId: widget.productId!,
                                              shopId: _selectedShopId!,
                                              categoryId: _selectedCategoryId!,
                                              title: title,
                                              description: desc,
                                              price: price,
                                              originalPrice: originalPrice,
                                              stock: stock,
                                              coverPath: finalCoverUrl,
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
                                              coverPath: finalCoverUrl,
                                              variants: _variants,
                                            ));
                                          }

                                          // Dismiss the loading dialog
                                          Navigator.of(context, rootNavigator: true).pop();

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(_isEditMode ? 'Cập nhật sản phẩm thành công!' : 'Đăng sản phẩm thành công!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          context.go('/products');
                                        } catch (e) {
                                          // Dismiss loading dialog if error occurs
                                          Navigator.of(context, rootNavigator: true).pop();
                                          setState(() {
                                            _isSaving = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Lỗi tải ảnh/lưu sản phẩm: $e'), backgroundColor: Colors.red),
                                          );
                                        }
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
