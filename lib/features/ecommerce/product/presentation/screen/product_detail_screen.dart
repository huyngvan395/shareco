import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:dartz/dartz.dart' hide State;

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/helpers/require_auth.dart';
import '../../../../../di/injector.dart';
import '../../../cart/domain/usecases/add_to_cart_usecase.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../bloc/product_detail/product_detail_bloc.dart';
import '../bloc/product_detail/product_detail_event.dart';
import '../bloc/product_detail/product_detail_state.dart';
import '../../../checkout/domain/entities/direct_order_args.dart';
import '../../../review/domain/entities/product_review_with_user.dart';
import '../../../review/domain/usecases/get_product_reviews_usecase.dart';
import '../widgets/product_gallery.dart';
import '../widgets/product_price.dart';
import '../widgets/product_variant_selector.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailBloc _bloc;
  ProductVariant? _selectedVariant;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _bloc = sl<ProductDetailBloc>()
      ..add(ProductDetailRequested(widget.productId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProductDetailBloc, ProductDetailState>(
        builder: (context, state) {
          final product = state is ProductDetailLoaded ? state.product : null;
          final selectedVariant =
              product == null ? null : _selectedVariantFor(product);
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              title: Text(
                product?.title ?? 'Product',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            body: _buildBody(state, selectedVariant),
            bottomNavigationBar: product == null
                ? null
                : _ProductActionBar(
                    product: product,
                    selectedVariant: selectedVariant,
                    isLoading: _isAddingToCart,
                    onAddToCart: () {
                      context.requireAuth(
                        () => _addToCart(product, selectedVariant),
                      );
                    },
                    onBuyNow: () {
                      context.requireAuth(
                        () => context.push('/checkout', extra: DirectOrderArgs(
                          product: product,
                          selectedVariant: selectedVariant,
                          qty: 1,
                        )),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    ProductDetailState state,
    ProductVariant? selectedVariant,
  ) {
    if (state is ProductDetailLoading || state is ProductDetailInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ProductDetailFailure) {
      return _StateMessage(
        icon: Icons.error_outline,
        title: state.message,
        onRetry: () => _bloc.add(ProductDetailRequested(widget.productId)),
      );
    }

    if (state is! ProductDetailLoaded) {
      return const SizedBox.shrink();
    }

    final product = state.product;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ProductGallery(product: product),
        ),
        SliverToBoxAdapter(
          child: _ProductInfo(
            product: product,
            selectedVariant: selectedVariant,
          ),
        ),
        if (product.variants.isNotEmpty)
          SliverToBoxAdapter(
            child: ProductVariantSelector(
              variants: product.variants,
              selectedVariant: selectedVariant,
              currency: product.currency,
              onChanged: (variant) {
                setState(() => _selectedVariant = variant);
              },
            ),
          ),
        SliverToBoxAdapter(
          child: _DescriptionSection(product: product),
        ),
        SliverToBoxAdapter(
          child: _ReviewsSection(productId: product.id),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 96),
        ),
      ],
    );
  }

  ProductVariant? _selectedVariantFor(Product product) {
    if (product.variants.isEmpty) return null;

    final current = _selectedVariant;
    if (current != null &&
        current.productId == product.id &&
        product.variants.any((variant) => variant.id == current.id)) {
      return current;
    }

    for (final variant in product.variants) {
      if (variant.isActive && variant.isInStock) return variant;
    }

    for (final variant in product.variants) {
      if (variant.isActive) return variant;
    }

    return product.variants.first;
  }

  Future<void> _addToCart(
    Product product,
    ProductVariant? selectedVariant,
  ) async {
    if (_isAddingToCart) return;

    setState(() => _isAddingToCart = true);
    final result = await sl<AddToCartUseCase>()(
      productId: product.id,
      variantId: selectedVariant?.id,
      qty: 1,
    );

    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
        );
      },
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final Product product;
  final ProductVariant? selectedVariant;

  const _ProductInfo({
    required this.product,
    required this.selectedVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductPrice(
            product: product,
            variant: selectedVariant,
            fontSize: 22,
          ),
          if (selectedVariant?.compareAtPrice != null &&
              selectedVariant!.compareAtPrice! > selectedVariant!.price) ...[
            const SizedBox(height: 3),
            Text(
              ProductPrice.formatAmount(
                selectedVariant!.compareAtPrice!,
                product.currency,
              ),
              style: const TextStyle(
                color: Colors.black38,
                decoration: TextDecoration.lineThrough,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Text(
            product.title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 18),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.push('/shop/${product.shopId}');
                  },
                  child: Text(
                    product.shopName ?? 'Shop',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Đã bán ${product.soldCount}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          if (product.brand != null && product.brand!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            GestureDetector(
              onTap: () {
                context.push('/shop/${product.shopId}');
              },
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: Color(0xFFEE4D2D), size: 18),
                  const SizedBox(width: AppSizes.xs),
                  const Text(
                    'Thương hiệu: ',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  Text(
                    product.brand!,
                    style: const TextStyle(
                      color: Color(0xFFEE4D2D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: AppSizes.xs),
              Text(
                '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount})',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(width: AppSizes.lg),
              Icon(
                _isInStock
                    ? Icons.inventory_2_outlined
                    : Icons.remove_shopping_cart_outlined,
                color: _isInStock ? Colors.green : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                _isInStock ? '$_stockQty sản phẩm có sẵn' : 'Hết hàng',
                style: TextStyle(
                  color: _isInStock ? Colors.green : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _stockQty => selectedVariant?.stockQty ?? product.stockTotal;

  bool get _isInStock => _stockQty > 0;
}

class _DescriptionSection extends StatelessWidget {
  final Product product;

  const _DescriptionSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final description = product.description?.trim();
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        0,
        AppSizes.xl,
        AppSizes.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSizes.xl),
          const Text(
            'Mô tả sản phẩm',
            style: TextStyle(
              color: Colors.black87,
              fontSize: AppSizes.fontXl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            description,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.45,
              fontSize: AppSizes.fontMd,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductActionBar extends StatelessWidget {
  final Product product;
  final ProductVariant? selectedVariant;
  final bool isLoading;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  const _ProductActionBar({
    required this.product,
    required this.selectedVariant,
    required this.isLoading,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _canBuy && !isLoading ? onAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: Text(isLoading ? 'Đang thêm...' : 'Thêm vào giỏ'),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canBuy && !isLoading ? onBuyNow : null,
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text('Mua ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canBuy {
    if (product.variants.isEmpty) return product.isInStock;
    return selectedVariant != null &&
        selectedVariant!.isActive &&
        selectedVariant!.isInStock;
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onRetry;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.onRetry,
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
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  final String productId;

  const _ReviewsSection({required this.productId});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  late final Future<Either<Failure, List<ProductReviewWithUser>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = sl<GetProductReviewsUseCase>()(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSizes.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Đánh giá sản phẩm',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: AppSizes.fontXl,
                  fontWeight: FontWeight.w800,
                ),
              ),
              FutureBuilder<Either<Failure, List<ProductReviewWithUser>>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final count = snapshot.data!.fold((_) => 0, (list) => list.length);
                    return Text(
                      '$count đánh giá',
                      style: const TextStyle(
                        color: Color(0xFFEE4D2D),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          FutureBuilder<Either<Failure, List<ProductReviewWithUser>>>(
            future: _reviewsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFEE4D2D),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }

              return snapshot.data!.fold(
                (failure) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                  child: Text(
                    'Không thể tải đánh giá: ${failure.message}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                (reviews) {
                  if (reviews.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.rate_review_outlined, color: Colors.grey[300], size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Chưa có đánh giá nào cho sản phẩm này.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final totalRating = reviews.fold<int>(0, (sum, item) => sum + item.rating);
                  final avgRating = totalRating / reviews.length;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE3E3)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  textBaseline: TextBaseline.alphabetic,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  children: [
                                    Text(
                                      avgRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Color(0xFFEE4D2D),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      '/5',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < avgRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            const Expanded(
                              child: Text(
                                'Tất cả đánh giá đều đến từ khách hàng đã mua sản phẩm này trên Shareco.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFF0F0F0),
                        ),
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFFFECE9),
                                  backgroundImage:
                                      review.userAvatar != null && review.userAvatar!.isNotEmpty
                                          ? NetworkImage(review.userAvatar!)
                                          : null,
                                  child: review.userAvatar == null || review.userAvatar!.isEmpty
                                      ? Text(
                                          review.userName.isNotEmpty
                                              ? review.userName[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Color(0xFFEE4D2D),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            review.userName,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (review.createdAt != null)
                                            Text(
                                              '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                                              style: const TextStyle(
                                                color: Colors.black38,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < review.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: Colors.amber,
                                            size: 14,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      if (review.content != null &&
                                          review.content!.trim().isNotEmpty)
                                        Text(
                                          review.content!.trim(),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
