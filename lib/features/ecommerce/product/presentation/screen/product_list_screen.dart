import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../cart/presentation/bloc/cart_event.dart';
import '../../../cart/presentation/bloc/cart_state.dart';
import '../bloc/product_list/product_list_bloc.dart';
import '../bloc/product_list/product_list_event.dart';
import '../bloc/product_list/product_list_state.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart' hide State;
import '../../../../../core/errors/failure.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_flash_sale_products_usecase.dart';
import '../widgets/product_card.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/services/ai/ai_search_service.dart';
import '../widgets/ai_scanning_overlay.dart';

class ProductListScreen extends StatefulWidget {
  final String? brand;

  const ProductListScreen({super.key, this.brand});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final ProductListBloc _bloc;
  late final CartBloc _cartBloc;
  final _searchCtrl = TextEditingController();

  File? _scannedImageFile;
  Future<String?>? _analysisFuture;
  String? _aiSearchKeyword;
  String? _selectedBrand;
  String? _selectedShopId;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.brand;
    _bloc = sl<ProductListBloc>()
      ..add(ProductListRequested(brand: _selectedBrand));
    _cartBloc = sl<CartBloc>()..add(const CartRequested());
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand) {
      _selectedBrand = widget.brand;
      _selectedShopId = null;
      _bloc.add(
        ProductListRequested(
          brand: _selectedBrand,
          search: _searchCtrl.text.trim(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bloc.close();
    _cartBloc.close();
    super.dispose();
  }

  void _loadProducts({String? search}) {
    _bloc.add(
      ProductListRequested(
        search: search,
        brand: _selectedBrand,
        shopId: _selectedShopId,
      ),
    );
  }

  void _onSelectBrand(String? brand, String? shopId) {
    setState(() {
      _selectedBrand = brand;
      _selectedShopId = shopId;
    });
    _bloc.add(
      ProductListRequested(
        search: _searchCtrl.text.trim(),
        brand: brand,
        shopId: shopId,
      ),
    );
  }

  void _onCameraTap() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tìm kiếm sản phẩm bằng AI 🧠',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy chụp ảnh hoặc chọn ảnh từ máy để AI tự động tìm sản phẩm',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndScanImage(ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Color(0xFFEE4D2D), size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Chụp ảnh mới',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndScanImage(ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.image_search_rounded, color: Colors.blueAccent, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Chọn từ thư viện',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _pickAndScanImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null || !mounted) return;

      final file = File(pickedFile.path);
      
      setState(() {
        _scannedImageFile = file;
        _analysisFuture = AiSearchService.analyzeProductImage(file);
      });

      final keyword = await _analysisFuture;
      if (!mounted) return;

      if (keyword != null && keyword.trim().isNotEmpty) {
        setState(() {
          _aiSearchKeyword = keyword.trim();
          _searchCtrl.text = _aiSearchKeyword!;
          _scannedImageFile = null;
          _analysisFuture = null;
        });
        _loadProducts(search: _aiSearchKeyword);
      } else {
        setState(() {
          _scannedImageFile = null;
          _analysisFuture = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI không thể nhận dạng sản phẩm. Vui lòng thử lại ảnh rõ nét hơn!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during AI image scanning: $e');
      if (!mounted) return;
      setState(() {
        _scannedImageFile = null;
        _analysisFuture = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _bloc),
          BlocProvider.value(value: _cartBloc),
        ],
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  _loadProducts(search: _searchCtrl.text.trim());
                },
                child: BlocBuilder<ProductListBloc, ProductListState>(
              builder: (context, state) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            BlocBuilder<CartBloc, CartState>(
                              builder: (context, cartState) {
                                final cartCount = cartState is CartLoaded 
                                    ? cartState.cart.items.fold<int>(0, (sum, item) => sum + item.qty) 
                                    : 0;
                                return _ShopHeader(
                                  controller: _searchCtrl,
                                  onSearch: (value) {
                                    setState(() {
                                      _aiSearchKeyword = null;
                                    });
                                    _loadProducts(search: value.trim());
                                  },
                                  onClear: () {
                                    setState(() {
                                      _aiSearchKeyword = null;
                                    });
                                    _searchCtrl.clear();
                                    _loadProducts();
                                  },
                                  cartCount: cartCount,
                                  onCartTap: () async {
                                    await context.push('/cart');
                                    if (mounted) {
                                      _cartBloc.add(const CartRequested());
                                    }
                                  },
                                  onCameraTap: _onCameraTap,
                                );
                              },
                            ),
                            _TopActionMenu(
                              selectedBrand: _selectedBrand,
                              selectedShopId: _selectedShopId,
                              onSelectBrand: _onSelectBrand,
                            ),
                            const SizedBox(height: 16),
                            _CategoriesGrid(
                              onSelectTab: (index) {
                                setState(() => _activeTabIndex = index);
                                DefaultTabController.maybeOf(context)
                                    ?.animateTo(index);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    const SliverToBoxAdapter(
                      child: _FlashSaleSection(),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabBarDelegate(
                        onTap: (index) {
                          if (_activeTabIndex != index) {
                            setState(() => _activeTabIndex = index);
                          }
                        },
                      ),
                    ),
                    if (_aiSearchKeyword != null)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEE4D2D), Color(0xFFFF7A00)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEE4D2D).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Outfit'),
                                    children: [
                                      const TextSpan(text: 'Kết quả quét ảnh '),
                                      const TextSpan(
                                        text: 'AI 🧠',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const TextSpan(text: ' cho: '),
                                      TextSpan(
                                        text: '"$_aiSearchKeyword"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _aiSearchKeyword = null;
                                    _searchCtrl.clear();
                                  });
                                  _loadProducts();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildContent(state),
                  ],
                );
              },
            ),
          ),
          if (_scannedImageFile != null && _analysisFuture != null)
            Positioned.fill(
              child: AiScanningOverlay(
                imageFile: _scannedImageFile!,
                analysisFuture: _analysisFuture!,
                onCancel: () {
                  setState(() {
                    _scannedImageFile = null;
                    _analysisFuture = null;
                  });
                },
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  List<Product> _filterProductsForActiveTab(List<Product> source) {
    switch (_activeTabIndex) {
      case 1: // Mall (Sản phẩm chính hãng có thương hiệu / cửa hàng)
        final mallList = source
            .where((p) =>
                (p.brand != null && p.brand!.trim().isNotEmpty) ||
                (p.shopName != null && p.shopName!.trim().isNotEmpty))
            .toList();
        return mallList.isNotEmpty ? mallList : source;
      case 2: // VOUCHER EXTRA (Sản phẩm đang giảm giá / ưu đãi)
        final discounted = source.where((p) {
          return p.variants.any(
            (v) =>
                v.isActive &&
                v.compareAtPrice != null &&
                v.compareAtPrice! > v.price,
          );
        }).toList();
        return discounted.isNotEmpty ? discounted : source;
      case 3: // Hàng Mới Về
        final newest = List<Product>.from(source);
        newest.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return newest;
      case 4: // Bán chạy
        final bestSelling = List<Product>.from(source);
        bestSelling.sort((a, b) {
          final cmp = b.soldCount.compareTo(a.soldCount);
          if (cmp != 0) return cmp;
          return b.ratingAvg.compareTo(a.ratingAvg);
        });
        return bestSelling;
      case 0:
      default:
        return source;
    }
  }

  Widget _buildContent(ProductListState state) {
    if (state is ProductListLoading || state is ProductListInitial) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFEE4D2D))),
      );
    }

    if (state is ProductListFailure) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.error_outline,
          title: state.message,
          actionLabel: 'Thử lại',
          onAction: () => _loadProducts(search: _searchCtrl.text.trim()),
        ),
      );
    }

    if (state is! ProductListLoaded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final displayedProducts = _filterProductsForActiveTab(state.products);

    if (displayedProducts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.search_off_rounded,
          title: _selectedBrand != null
              ? 'Chưa có sản phẩm nào thuộc nhãn hàng "$_selectedBrand"'
              : 'Không tìm thấy sản phẩm nào',
          actionLabel: _selectedBrand != null ? 'Xem tất cả sản phẩm' : 'Làm mới',
          onAction: () {
            if (_selectedBrand != null || _selectedShopId != null) {
              _onSelectBrand(null, null);
            } else {
              _loadProducts();
            }
          },
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSizes.sm, AppSizes.sm, AppSizes.sm, AppSizes.xl),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = displayedProducts[index];
            return ProductCard(
              product: product,
              onTap: () async {
                await context.push('/products/${product.id}');
                if (mounted) {
                  _cartBloc.add(const CartRequested());
                }
              },
            );
          },
          childCount: displayedProducts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.sm,
          crossAxisSpacing: AppSizes.sm,
          childAspectRatio: 0.55, // Adjusted to prevent overflow
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final int cartCount;
  final VoidCallback onCartTap;
  final VoidCallback onCameraTap;

  const _ShopHeader({
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.cartCount,
    required this.onCartTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEE4D2D), width: 1.5),
                borderRadius: BorderRadius.circular(21),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.black54, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (_, value, __) => TextField(
                        controller: controller,
                        onSubmitted: onSearch,
                        decoration: InputDecoration(
                          hintText: 'Nhập sản phẩm bạn muốn tìm kiếm',
                          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: onClear,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCameraTap,
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 22),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onSearch(controller.text),
                    child: const Text(
                      'Tìm kiếm',
                      style: TextStyle(
                        color: Color(0xFFEE4D2D),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _showVouchersBottomSheet(context),
            child: const Icon(Icons.confirmation_num_outlined, color: Color(0xFFEE4D2D), size: 28),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onCartTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.black87, size: 28),
                if (cartCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEE4D2D),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cartCount > 99 ? '99+' : cartCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionMenu extends StatefulWidget {
  final String? selectedBrand;
  final String? selectedShopId;
  final void Function(String? brand, String? shopId) onSelectBrand;

  const _TopActionMenu({
    required this.selectedBrand,
    required this.selectedShopId,
    required this.onSelectBrand,
  });

  @override
  State<_TopActionMenu> createState() => _TopActionMenuState();
}

class _TopActionMenuState extends State<_TopActionMenu> {
  late final Future<List<Map<String, dynamic>>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _fetchShopsAndBrands();
  }

  static String _formatBrandLabel(String rawName) {
    final cleaned = rawName
        .replaceAll(
          RegExp(
            r'\b(official|flagship|store|shop|mall|cửa hàng|cua hang)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? rawName.trim() : cleaned;
  }

  Future<List<Map<String, dynamic>>> _fetchShopsAndBrands() async {
    try {
      final supabase = Supabase.instance.client;
      final shopsFuture = supabase
          .from('shops')
          .select('id, shop_name, logo_path')
          .eq('status', 'active')
          .order('created_at', ascending: true);
      final productsFuture = supabase
          .from('products')
          .select('brand, shop_id')
          .eq('status', 'active');

      final shopsData = await shopsFuture;
      final productsData = await productsFuture;

      final result = <Map<String, dynamic>>[];
      final seenKeys = <String>{};

      for (final row in (shopsData as List).whereType<Map<String, dynamic>>()) {
        final rawName = (row['shop_name'] as String? ?? '').trim();
        if (rawName.isEmpty) continue;
        final label = _formatBrandLabel(rawName);
        final key = label.toLowerCase();
        seenKeys.add(key);
        seenKeys.add(rawName.toLowerCase());
        result.add({
          'id': row['id'] as String?,
          'shop_name': rawName,
          'label': label,
          'logo_path': row['logo_path'] as String?,
        });
      }

      for (final prod
          in (productsData as List).whereType<Map<String, dynamic>>()) {
        final rawBrand = (prod['brand'] as String? ?? '').trim();
        if (rawBrand.isEmpty) continue;
        final label = _formatBrandLabel(rawBrand);
        final key = label.toLowerCase();
        if (seenKeys.contains(key) ||
            seenKeys.contains(rawBrand.toLowerCase())) {
          continue;
        }
        seenKeys.add(key);
        seenKeys.add(rawBrand.toLowerCase());
        result.add({
          'id': prod['shop_id'] as String?,
          'shop_name': rawBrand,
          'label': label,
          'logo_path': null,
        });
      }

      return result;
    } catch (e) {
      debugPrint('Lỗi tải danh sách nhãn hàng: $e');
      return [];
    }
  }

  Widget _buildBrandItem({
    required String label,
    required Widget image,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFEE4D2D), Color(0xFFFF7A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade200],
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFEE4D2D).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: image,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFEE4D2D) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _shopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 94,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEE4D2D),
                ),
              ),
            ),
          );
        }

        final shops = snapshot.data ?? [];
        final selectedBrand = widget.selectedBrand;
        final selectedShopId = widget.selectedShopId;
        final isAllSelected = selectedBrand == null && selectedShopId == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
              child: Row(
                children: [
                  _buildBrandItem(
                    label: 'Tất cả',
                    image: Center(
                      child: Icon(
                        Icons.apps_rounded,
                        size: 28,
                        color: isAllSelected
                            ? const Color(0xFFEE4D2D)
                            : Colors.black54,
                      ),
                    ),
                    isSelected: isAllSelected,
                    onTap: () => widget.onSelectBrand(null, null),
                  ),
                  ...shops.map((shop) {
                    final shopId = shop['id'] as String?;
                    final label =
                        (shop['label'] as String? ?? 'Shop').trim();
                    final brandInitial = label.isNotEmpty
                        ? label.substring(0, 1).toUpperCase()
                        : 'S';
                    final isSelected = (selectedShopId != null &&
                            selectedShopId == shopId &&
                            selectedBrand == label) ||
                        (selectedBrand != null &&
                            selectedBrand.toLowerCase() ==
                                label.toLowerCase());
                    final rawLogoPath = shop['logo_path'] as String?;
                    final logoUrl = StorageImage.publicUrl(
                      rawLogoPath,
                      bucket: 'avatars',
                    );

                    return _buildBrandItem(
                      label: label,
                      image: logoUrl != null && logoUrl.isNotEmpty
                          ? Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    brandInitial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black54,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                brandInitial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                      isSelected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          widget.onSelectBrand(null, null);
                        } else {
                          widget.onSelectBrand(label, shopId);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
            if (!isAllSelected)
              Container(
                margin: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  6,
                  AppSizes.md,
                  0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEE4D2D).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFEE4D2D),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nhãn hàng: ${selectedBrand ?? "Shop"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (selectedShopId != null && selectedShopId.isNotEmpty)
                      InkWell(
                        onTap: () => context.push('/shop/$selectedShopId'),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEE4D2D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Xem Shop',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => widget.onSelectBrand(null, null),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _CategoriesGrid({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.local_offer_outlined, 'label': 'Voucher', 'color': const Color(0xFFEE4D2D)},
      {'icon': Icons.receipt_long_outlined, 'label': 'Đơn hàng', 'color': Colors.blue},
      {'icon': Icons.add_business_outlined, 'label': 'Đăng ký bán', 'color': Colors.teal},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Chính hãng', 'color': Colors.orange},
      {'icon': Icons.location_on_outlined, 'label': 'Địa chỉ', 'color': Colors.pink},
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            return Expanded(
              child: InkWell(
                onTap: () {
                  final label = item['label'] as String;
                  if (label == 'Voucher') {
                    _showVouchersBottomSheet(context);
                  } else if (label == 'Đơn hàng') {
                    context.push('/orders');
                  } else if (label == 'Đăng ký bán') {
                    context.push('/register-seller');
                  } else if (label == 'Chính hãng') {
                    onSelectTab?.call(1);
                  } else if (label == 'Địa chỉ') {
                    context.push('/addresses');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.2, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 16, height: 4, decoration: BoxDecoration(color: const Color(0xFFEE4D2D), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle)),
          ],
        ),
      ],
    );
  }
}

class _FlashSaleSection extends StatefulWidget {
  const _FlashSaleSection();

  @override
  State<_FlashSaleSection> createState() => _FlashSaleSectionState();
}

class _FlashSaleSectionState extends State<_FlashSaleSection> {
  late Future<Either<Failure, List<Product>>> _flashSaleFuture;
  Timer? _timer;
  final ValueNotifier<Duration> _remainingTimeNotifier =
      ValueNotifier<Duration>(Duration.zero);
  int _currentSlotStartHour = 0;

  @override
  void initState() {
    super.initState();
    _flashSaleFuture = sl<GetFlashSaleProductsUseCase>().call();
    _calculateSessionTime(notifySlotChange: false);
    _startTimer();
  }

  void _calculateSessionTime({bool notifySlotChange = true}) {
    final now = DateTime.now();
    final hour = now.hour;

    // Define slots: [0-9, 9-12, 12-15, 15-18, 18-21, 21-24]
    int startHour = 0;
    int endHour = 0;

    if (hour >= 21) {
      startHour = 21;
      endHour = 24;
    } else if (hour >= 18) {
      startHour = 18;
      endHour = 21;
    } else if (hour >= 15) {
      startHour = 15;
      endHour = 18;
    } else if (hour >= 12) {
      startHour = 12;
      endHour = 15;
    } else if (hour >= 9) {
      startHour = 9;
      endHour = 12;
    } else {
      startHour = 0;
      endHour = 9;
    }

    final slotChanged = _currentSlotStartHour != startHour;
    _currentSlotStartHour = startHour;

    final targetTime = endHour == 24
        ? DateTime(now.year, now.month, now.day + 1, 0, 0, 0)
        : DateTime(now.year, now.month, now.day, endHour, 0, 0);

    _remainingTimeNotifier.value = targetTime.difference(now);
    if (notifySlotChange && slotChanged && mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = _remainingTimeNotifier.value;
      if (current.inSeconds <= 0) {
        _calculateSessionTime();
      } else {
        _remainingTimeNotifier.value = current - const Duration(seconds: 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingTimeNotifier.dispose();
    super.dispose();
  }

  String _formatTwoDigits(int number) {
    return number.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, List<Product>>>(
      future: _flashSaleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFEE4D2D),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final result = snapshot.data!;
        return result.fold(
          (failure) => const SizedBox.shrink(),
          (products) {
            if (products.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: Color(0xFFEE4D2D),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'FLASH SALE',
                          style: TextStyle(
                            color: Color(0xFFEE4D2D),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAE6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'KHUNG $_currentSlotStartHour:00 🔥',
                            style: const TextStyle(
                              color: Color(0xFFEE4D2D),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<Duration>(
                          valueListenable: _remainingTimeNotifier,
                          builder: (_, remaining, __) {
                            final hours = _formatTwoDigits(remaining.inHours);
                            final minutes = _formatTwoDigits(
                              remaining.inMinutes.remainder(60),
                            );
                            final seconds = _formatTwoDigits(
                              remaining.inSeconds.remainder(60),
                            );
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTimerBox(hours),
                                const Text(
                                  ' : ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEE4D2D),
                                    fontSize: 12,
                                  ),
                                ),
                                _buildTimerBox(minutes),
                                const Text(
                                  ' : ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEE4D2D),
                                    fontSize: 12,
                                  ),
                                ),
                                _buildTimerBox(seconds),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        
                        final activeVariants = product.variants.where((v) => v.status == 'active').toList();
                        if (activeVariants.isEmpty) return const SizedBox.shrink();

                        final variant = activeVariants.firstWhere(
                          (v) => v.compareAtPrice != null && v.compareAtPrice! > v.price,
                          orElse: () => activeVariants.first,
                        );

                        final price = variant.price;
                        final originalPrice = variant.compareAtPrice ?? price;
                        final discountPercent = originalPrice > price
                            ? ((originalPrice - price) / originalPrice * 100).round()
                            : 0;

                        final totalStock = product.stockTotal + product.soldCount;
                        final soldRatio = totalStock > 0
                            ? (product.soldCount / totalStock)
                            : 0.0;
                        final displayRatio = soldRatio > 0.0 ? soldRatio : 0.25;

                        final coverUrl = StorageImage.publicUrl(product.coverPath);

                        return GestureDetector(
                          onTap: () async {
                            await context.push('/products/${product.id}');
                            if (context.mounted) {
                              context.read<CartBloc>().add(const CartRequested());
                            }
                          },
                          child: Container(
                            width: 130,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black.withOpacity(0.03)),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: coverUrl != null && coverUrl.isNotEmpty
                                              ? Image.network(
                                                  coverUrl,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, _, __) => const Center(
                                                    child: Icon(Icons.image, color: Colors.grey),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.image, color: Colors.grey),
                                                ),
                                        ),
                                        if (discountPercent > 0)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFFE100),
                                                borderRadius: BorderRadius.only(
                                                  bottomLeft: Radius.circular(8),
                                                  topRight: Radius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                '-$discountPercent%',
                                                style: const TextStyle(
                                                  color: Color(0xFFEE4D2D),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₫${NumberFormat.decimalPattern('vi_VN').format(price)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFEE4D2D),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD5CD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: displayRatio,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFF7A00),
                                                Color(0xFFEE4D2D),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          product.soldCount > 0
                                              ? 'Đã Bán ${product.soldCount}'
                                              : 'SẮP HẾT HÀNG 🔥',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimerBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEE4D2D),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final ValueChanged<int>? onTap;

  _StickyTabBarDelegate({this.onTap});

  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.black87,
        indicatorWeight: 3,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
        onTap: onTap,
        tabs: const [
          Tab(text: 'Tất cả'),
          Tab(text: 'Mall'),
          Tab(text: 'VOUCHER EXTRA'),
          Tab(text: 'Hàng Mới Về'),
          Tab(text: 'Bán Chạy'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      oldDelegate.onTap != onTap;
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 42),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: AppSizes.md),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFFEE4D2D))),
            ),
          ],
        ),
      ),
    );
  }
}

void _showVouchersBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final vouchers = [
        {
          'code': 'SHARECOSALE10',
          'title': 'Giảm giá 10% đơn hàng',
          'subtitle': 'Giảm ngay 10% (Tối đa 50.000đ) cho tất cả đơn hàng trên hệ thống Shareco.',
          'icon': Icons.stars,
          'color': const Color(0xFF6200EE),
          'min': 0.0,
        },
        {
          'code': 'SHARECOVIP',
          'title': 'Tri ân VIP thành viên',
          'subtitle': 'Ưu đãi đặc quyền giảm giá 20% (Tối đa 100.000đ) cho khách hàng VIP.',
          'icon': Icons.workspace_premium,
          'color': const Color(0xFFFFB300),
          'min': 0.0,
        },
        {
          'code': 'DEALKHUNG',
          'title': 'Siêu Deal Giảm 50K',
          'subtitle': 'Giảm trực tiếp 50.000đ cho đơn hàng có giá trị thanh toán từ 200.000đ trở lên.',
          'icon': Icons.local_fire_department,
          'color': const Color(0xFFFF2D55),
          'min': 200000.0,
        },
        {
          'code': 'FREESHIP',
          'title': 'Miễn phí vận chuyển toàn quốc',
          'subtitle': 'Hỗ trợ tối đa 30.000đ chi phí vận chuyển toàn hệ thống.',
          'icon': Icons.local_shipping,
          'color': const Color(0xFF00C853),
          'min': 0.0,
        },
      ];

      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.lg),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sheet Title
            const Row(
              children: [
                Icon(Icons.local_activity_outlined, color: Color(0xFFEE4D2D), size: 24),
                SizedBox(width: 8),
                Text(
                  'Kho Voucher Của Bạn 🎟️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm "Sao chép" để lưu mã khuyến mãi và áp dụng trực tiếp tại bước thanh toán đặt hàng.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            // Vouchers List
            Expanded(
              child: ListView.builder(
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
                  final v = vouchers[index];
                  final String code = v['code'] as String;
                  return _VoucherCouponCard(
                    code: code,
                    title: v['title'] as String,
                    subtitle: v['subtitle'] as String,
                    icon: v['icon'] as IconData,
                    color: v['color'] as Color,
                    minSubtotal: v['min'] as double,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đã sao chép mã "$code" thành công! Sử dụng tại trang Checkout.',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF00C853),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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

class _VoucherCouponCard extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double minSubtotal;
  final VoidCallback onTap;

  const _VoucherCouponCard({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.minSubtotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Left part (brand styling)
            Container(
              width: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Dashed separator
            CustomPaint(
              size: const Size(1, double.infinity),
              painter: _TicketSeparatorPainter(color: Colors.black12),
            ),
            // Right part (details)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (minSubtotal > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Đơn tối thiểu từ ${minSubtotal.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ',
                              style: const TextStyle(
                                color: Color(0xFFEE4D2D),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action button
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 28),
                      ),
                      child: const Text(
                        'Sao chép',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
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

class _TicketSeparatorPainter extends CustomPainter {
  final Color color;
  _TicketSeparatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashHeight = 4;
    const double dashSpace = 3;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
