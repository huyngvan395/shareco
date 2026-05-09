import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../order/domain/entities/order_item.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';

class ReviewFormScreen extends StatefulWidget {
  final OrderItem orderItem;

  const ReviewFormScreen({super.key, required this.orderItem});

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  late final ReviewBloc _bloc;
  final _contentCtrl = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _bloc = sl<ReviewBloc>();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _bloc.add(ReviewSubmitted(
      productId: widget.orderItem.productId,
      orderItemId: widget.orderItem.id,
      rating: _rating,
      content: _contentCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đánh giá sản phẩm'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        backgroundColor: Colors.grey[50],
        body: BlocConsumer<ReviewBloc, ReviewState>(
          listener: (context, state) {
            if (state is ReviewSubmitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cảm ơn bạn đã đánh giá sản phẩm!'),
                  backgroundColor: Colors.green,
                ),
              );
              context.pop(true); // Return true to indicate success
            } else if (state is ReviewSubmitFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ReviewSubmitting;
            final imageUrl = StorageImage.publicUrl(widget.orderItem.imagePath, bucket: 'product-media');

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Product Preview
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.black26),
                                  )
                                : const Icon(Icons.image_not_supported, color: Colors.black26),
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.orderItem.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (widget.orderItem.variantName != null) ...[
                                const SizedBox(height: AppSizes.xs),
                                Text(
                                  'Phân loại: ${widget.orderItem.variantName}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // Rating Section
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
                    child: Column(
                      children: [
                        const Text(
                          'Chất lượng sản phẩm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            return GestureDetector(
                              onTap: () {
                                if (!isLoading) {
                                  setState(() => _rating = star);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(
                                  star <= _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 40,
                                  color: star <= _rating
                                      ? const Color(0xFFFFB800)
                                      : Colors.grey[300],
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          _getRatingText(_rating),
                          style: const TextStyle(
                            color: Color(0xFFFFB800),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // Comment Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'Hãy chia sẻ nhận xét của bạn về sản phẩm này nhé!',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F4F4),
                        contentPadding: const EdgeInsets.all(AppSizes.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: BlocBuilder<ReviewBloc, ReviewState>(
              builder: (context, state) {
                final isLoading = state is ReviewSubmitting;
                return ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Gửi đánh giá',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Tệ';
      case 2:
        return 'Không hài lòng';
      case 3:
        return 'Bình thường';
      case 4:
        return 'Hài lòng';
      case 5:
        return 'Tuyệt vời';
      default:
        return '';
    }
  }
}
