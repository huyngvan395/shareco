import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/helpers/require_auth.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../../../routes/app_router.dart';
import '../../../../chat/domain/usecases/chat_usecases.dart';
import '../../../../profile/data/datasources/profile_remote_datasource.dart';
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
  bool _isFollowing = false;

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
    final isOwner = SupabaseService.currentUserId != null &&
        SupabaseService.currentUserId == shop.ownerId;

    return SliverAppBar(
      expandedHeight: 235,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      actions: [
        IconButton(
          tooltip: 'Chia sẻ cửa hàng',
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    'Ghé thăm gian hàng "${shop.shopName}" trên ShareCo: https://shareco/shop/${shop.id}',
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Giỏ hàng',
          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          onPressed: () => context.requireAuth(() => context.push('/cart')),
        ),
      ],
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
            Container(color: Colors.black.withValues(alpha: 0.45)),

            // Shop Info Overlay
            Positioned(
              left: 16,
              bottom: 14,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Logo
                  Container(
                    width: 68,
                    height: 68,
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
                        ? const Icon(Icons.storefront,
                            color: Colors.grey, size: 34)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Shop Name, Badges & Warehouse
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shop.shopName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (shop.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF29B6F6),
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${shop.followerCount + (_isFollowing ? 1 : 0)} Người theo dõi',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (shop.pickupProvince != null &&
                            shop.pickupProvince!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '📍 Kho: ${shop.pickupHubLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Actions: Owner -> Seller Center | Buyer -> Chat + Follow
                  if (isOwner)
                    InkWell(
                      onTap: () {
                        context.push(
                          Routes.sellerCenter,
                          extra: {'shopId': shop.id},
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: Color(0xFFEE4D2D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Kênh bán',
                              style: TextStyle(
                                color: Color(0xFFEE4D2D),
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Chat Button
                        GestureDetector(
                          onTap: () {
                            context.requireAuth(() async {
                              try {
                                final getOrCreateShop =
                                    sl<GetOrCreateShopConversationUseCase>();
                                final res = await getOrCreateShop(
                                  shopId: shop.id,
                                  ownerId: shop.ownerId,
                                  shopName: shop.shopName,
                                  shopLogo: shop.logoPath,
                                  isShopVerified: shop.isVerified,
                                );
                                if (!context.mounted) return;
                                res.fold(
                                  (l) => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(content: Text(l.message)),
                                  ),
                                  (conv) => context.push(
                                    Routes.messages,
                                    extra: conv,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Không thể mở chat: $e')),
                                );
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Chat',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Follow Button
                        GestureDetector(
                          onTap: () {
                            context.requireAuth(() async {
                              setState(() {
                                _isFollowing = !_isFollowing;
                              });
                              if (shop.ownerId.isNotEmpty) {
                                try {
                                  await sl<ProfileRemoteDataSource>()
                                      .toggleFollow(shop.ownerId);
                                } catch (_) {}
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isFollowing
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                              border: _isFollowing
                                  ? Border.all(color: Colors.white70)
                                  : null,
                            ),
                            child: Text(
                              _isFollowing ? 'Đang theo dõi' : '+ Theo dõi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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
    final actualProductCount = state.products.length > shop.productCount
        ? state.products.length
        : shop.productCount;
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
            _buildStatItem(Icons.inventory_2_outlined, '$actualProductCount', 'Sản phẩm'),
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
