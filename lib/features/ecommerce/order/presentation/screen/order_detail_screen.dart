import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../domain/entities/ecommerce_order.dart';
import '../../domain/entities/order_item.dart';
import '../bloc/order_detail/order_detail_bloc.dart';
import '../bloc/order_detail/order_detail_event.dart';
import '../bloc/order_detail/order_detail_state.dart';
import '../widgets/order_formatters.dart';
import '../widgets/order_status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderDetailBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<OrderDetailBloc>()..add(OrderDetailRequested(widget.orderId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _reload() {
    _bloc.add(OrderDetailRequested(widget.orderId));
  }

  Future<void> _confirmCancel(EcommerceOrder order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hủy đơn hàng?'),
          content: Text(
            'Đơn #${order.orderCode} sẽ được chuyển sang trạng thái đã hủy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Không'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Hủy đơn',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      _bloc.add(OrderCancelRequested(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: const Text(
            'Chi tiết đơn hàng',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: BlocConsumer<OrderDetailBloc, OrderDetailState>(
          listener: (context, state) {
            if (state is OrderDetailCancelFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
            if (state is OrderDetailCancelSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã hủy đơn hàng')),
              );
            }
          },
          builder: (context, state) {
            if (state is OrderDetailInitial || state is OrderDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is OrderDetailFailure) {
              return _StateMessage(
                icon: Icons.error_outline_rounded,
                title: state.message,
                actionLabel: 'Thử lại',
                onAction: _reload,
              );
            }

            final order = _orderFromState(state);
            if (order == null) return const SizedBox.shrink();

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.xl,
                ),
                children: [
                  _StatusSection(
                    order: order,
                    isCancelling: state is OrderDetailCancelling,
                    onCancel: () => _confirmCancel(order),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _ItemsSection(order: order, onReviewSuccess: _reload),
                  const SizedBox(height: AppSizes.md),
                  _AddressSection(order: order),
                  const SizedBox(height: AppSizes.md),
                  _PaymentSection(order: order),
                  const SizedBox(height: AppSizes.md),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/ecommerce'),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Tiếp tục mua sắm'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  EcommerceOrder? _orderFromState(OrderDetailState state) {
    if (state is OrderDetailLoaded) return state.order;
    if (state is OrderDetailCancelling) return state.order;
    if (state is OrderDetailCancelSuccess) return state.order;
    if (state is OrderDetailCancelFailure) return state.order;
    return null;
  }
}

class _StatusSection extends StatelessWidget {
  final EcommerceOrder order;
  final bool isCancelling;
  final VoidCallback onCancel;

  const _StatusSection({
    required this.order,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.orderCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              OrderStatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Đặt lúc ${formatOrderDate(order.placedAt)}',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (order.status == 'pending') ...[
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isCancelling ? null : onCancel,
                icon: isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  final EcommerceOrder order;
  final VoidCallback? onReviewSuccess;

  const _ItemsSection({
    required this.order,
    this.onReviewSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: order.shopName ?? 'Shop',
      titleIcon: Icons.storefront_outlined,
      child: Column(
        children: order.items.map((item) {
          return _OrderItemRow(
            item: item,
            currency: order.currency,
            orderStatus: order.status,
            onTap: () => context.push('/products/${item.productId}'),
            onReviewSuccess: onReviewSuccess,
          );
        }).toList(),
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  final EcommerceOrder order;

  const _AddressSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final address = order.addressSnapshot;
    final fullName = _value(address, 'full_name');
    final phone = _value(address, 'phone');
    final line = _value(address, 'address_line');
    final location = [
      _value(address, 'ward'),
      _value(address, 'district'),
      _value(address, 'province'),
    ].where((value) => value.isNotEmpty).join(', ');

    final cleanedNote = _cleanNote(order.note);

    return _SectionCard(
      title: 'Địa chỉ nhận hàng',
      titleIcon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$fullName · $phone',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            [line, location].where((value) => value.isNotEmpty).join(', '),
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
          if (cleanedNote.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              'Ghi chú: $cleanedNote',
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  String _cleanNote(String? note) {
    if (note == null) return '';
    final regExp = RegExp(r'\[Thanh toán: [^\]]+\]\s*');
    return note.replaceAll(regExp, '').trim();
  }

  static String _value(Map<String, dynamic> map, String key) {
    return map[key]?.toString().trim() ?? '';
  }
}

class _PaymentSection extends StatelessWidget {
  final EcommerceOrder order;

  const _PaymentSection({required this.order});

  String _getPaymentMethodLabel() {
    final method = order.addressSnapshot['payment_method'] as String?;
    if (method == 'cod') return 'Tiền mặt (COD)';
    if (method == 'card') return 'Thẻ Visa/Mastercard';
    if (method == 'qr') return 'QR Chuyển khoản';

    // Fallback parser from note
    if (order.note != null) {
      if (order.note!.contains('Tiền mặt (COD)')) return 'Tiền mặt (COD)';
      if (order.note!.contains('Thẻ Visa/Mastercard')) return 'Thẻ Visa/Mastercard';
      if (order.note!.contains('QR Chuyển khoản')) return 'QR Chuyển khoản';
    }
    return 'Tiền mặt (COD)'; // Default fallback
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Thanh toán',
      titleIcon: Icons.payments_outlined,
      child: Column(
        children: [
          _AmountRow(
            label: 'Tạm tính',
            value: formatOrderAmount(order.subtotalAmount, order.currency),
          ),
          const SizedBox(height: AppSizes.sm),
          _AmountRow(
            label: 'Giảm giá',
            value: '-${formatOrderAmount(order.discountAmount, order.currency)}',
          ),
          const SizedBox(height: AppSizes.sm),
          _AmountRow(
            label: 'Vận chuyển',
            value: formatOrderAmount(order.shippingAmount, order.currency),
          ),
          const Divider(height: 24),
          _AmountRow(
            label: 'Phương thức',
            value: _getPaymentMethodLabel(),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSizes.sm),
          _AmountRow(
            label: 'Tổng thanh toán',
            value: formatOrderAmount(order.totalAmount, order.currency),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? color;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black87 : Colors.black54,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? (isTotal ? AppColors.primary : Colors.black87),
            fontSize: isTotal ? AppSizes.fontXl : AppSizes.fontMd,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final String currency;
  final String orderStatus;
  final VoidCallback onTap;
  final VoidCallback? onReviewSuccess;

  const _OrderItemRow({
    required this.item,
    required this.currency,
    required this.orderStatus,
    required this.onTap,
    this.onReviewSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.md),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderItemImage(path: item.imagePath),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (item.variantName != null && item.variantName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            item.variantName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        '${formatOrderAmount(item.unitPrice, currency)} x${item.qty}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    formatOrderAmount(item.lineTotal, currency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            _buildReviewButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewButton(BuildContext context) {
    if (orderStatus != 'completed') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () async {
            final success = await context.push('/review/new', extra: item);
            if (success == true) {
              onReviewSuccess?.call();
            }
          },
          icon: const Icon(Icons.star_outline_rounded, size: 18),
          label: const Text('Đánh giá sản phẩm'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
      ),
    );
  }
}

class _OrderItemImage extends StatelessWidget {
  final String? path;

  const _OrderItemImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final url = StorageImage.publicUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: 68,
        height: 68,
        color: const Color(0xFFEFEFEF),
        child: url == null
            ? const Icon(Icons.shopping_bag_outlined, color: Colors.black38)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.black38,
                ),
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Widget child;

  const _SectionCard({
    this.title,
    this.titleIcon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 18, color: Colors.black87),
                  const SizedBox(width: AppSizes.xs),
                ],
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: AppSizes.fontXl,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
          ],
          child,
        ],
      ),
    );
  }
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
            Icon(icon, color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
