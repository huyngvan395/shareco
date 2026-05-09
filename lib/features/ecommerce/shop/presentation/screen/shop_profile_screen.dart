import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../product/presentation/widgets/product_card.dart';
import '../bloc/shop_profile_bloc.dart';
import '../bloc/shop_profile_event.dart';
import '../bloc/shop_profile_state.dart';

class ShopProfileScreen extends StatefulWidget {
  final String shopId;

  const ShopProfileScreen({super.key, required this.shopId});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  late final ShopProfileBloc _bloc;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bloc = sl<ShopProfileBloc>()..add(ShopProfileRequested(widget.shopId));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _bloc.add(ShopProductsFiltered(widget.shopId, query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: BlocBuilder<ShopProfileBloc, ShopProfileState>(
          builder: (context, state) {
            if (state is ShopProfileLoading || state is ShopProfileInitial) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEE4D2D)));
            }

            if (state is ShopProfileFailure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.grey, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEE4D2D)),
                      onPressed: () => _bloc.add(ShopProfileRequested(widget.shopId)),
                      child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            if (state is ShopProfileLoaded) {
              return CustomScrollView(
                slivers: [
                  _buildSliverAppBar(state),
                  _buildShopStats(state),
                  _buildSearchBar(),
                  _buildProductGrid(state),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CupertinoSearchTextField(
          controller: _searchCtrl,
          placeholder: 'Tìm kiếm sản phẩm trong shop...',
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(ShopProfileLoaded state) {
    final shop = state.shop;
    final coverUrl = StorageImage.publicUrl(shop.coverPath, bucket: 'avatars');
    final logoUrl = StorageImage.publicUrl(shop.logoPath, bucket: 'avatars');

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            if (coverUrl != null)
              Image.network(coverUrl, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[300]),
            
            // Dark Overlay
            Container(color: Colors.black.withValues(alpha: 0.4)),
            
            // Shop Info Overlay
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Logo
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image: logoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(logoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: logoUrl == null
                        ? const Icon(Icons.storefront, color: Colors.grey, size: 36)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Shop Name & Followers
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shop.shopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${shop.followerCount} Người theo dõi',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Follow Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEE4D2D),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '+ Theo dõi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
  }

  Widget _buildShopStats(ShopProfileLoaded state) {
    final shop = state.shop;
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.star_rounded, '${shop.ratingAvg.toStringAsFixed(1)}/5.0', 'Đánh giá', color: Colors.amber),
            _buildDivider(),
            _buildStatItem(Icons.inventory_2_outlined, '${shop.productCount}', 'Sản phẩm'),
            _buildDivider(),
            _buildStatItem(Icons.chat_outlined, '98%', 'Phản hồi'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color color = Colors.black54}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEE4D2D))),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 30, color: Colors.grey[300]);
  }

  Widget _buildProductGrid(ShopProfileLoaded state) {
    if (state.products.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'Shop chưa có sản phẩm nào',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = state.products[index];
            return ProductCard(
              product: product,
              onTap: () => context.push('/products/${product.id}'),
            );
          },
          childCount: state.products.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.55,
        ),
      ),
    );
  }
}
