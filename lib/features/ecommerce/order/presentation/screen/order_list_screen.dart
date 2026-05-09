import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../domain/entities/ecommerce_order.dart';
import '../../domain/entities/order_item.dart';
import '../bloc/order_list/order_list_bloc.dart';
import '../bloc/order_list/order_list_event.dart';
import '../bloc/order_list/order_list_state.dart';
import '../widgets/order_formatters.dart';
import '../widgets/order_status_badge.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late final OrderListBloc _bloc;
  String? _status;

  static const _tabs = [
    _OrderTab(label: 'Tất cả'),
    _OrderTab(label: 'Chờ xử lý', status: 'pending'),
    _OrderTab(label: 'Đã thanh toán', status: 'paid'),
    _OrderTab(label: 'Đóng gói', status: 'packed'),
    _OrderTab(label: 'Đang giao', status: 'shipping'),
    _OrderTab(label: 'Hoàn thành', status: 'completed'),
    _OrderTab(label: 'Đã hủy', status: 'cancelled'),
    _OrderTab(label: 'Hoàn tiền', status: 'refunded'),
  ];

  @override
  void initState() {
    super.initState();
    _bloc = sl<OrderListBloc>()..add(const OrderListRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _loadOrders({String? status}) {
    _bloc.add(OrderListRequested(status: status));
  }

  void _selectStatus(String? status) {
    if (_status == status) return;
    setState(() => _status = status);
    _loadOrders(status: status);
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/ecommerce');
              }
            },
          ),
          title: const Text(
            'Đơn hàng của tôi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Column(
          children: [
            _OrderTabs(
              tabs: _tabs,
              selectedStatus: _status,
              onChanged: _selectStatus,
            ),
            Expanded(
              child: BlocBuilder<OrderListBloc, OrderListState>(
                builder: (context, state) {
                  if (state is OrderListInitial || state is OrderListLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is OrderListFailure) {
                    return _StateMessage(
                      icon: Icons.error_outline_rounded,
                      title: state.message,
                      actionLabel: 'Thử lại',
                      onAction: () => _loadOrders(status: _status),
                    );
                  }

                  if (state is! OrderListLoaded) {
                    return const SizedBox.shrink();
                  }

                  if (state.orders.isEmpty) {
                    return _StateMessage(
                      icon: Icons.receipt_long_outlined,
                      title: 'Chưa có đơn hàng',
                      actionLabel: 'Mua sắm ngay',
                      onAction: () => context.go('/ecommerce'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _loadOrders(status: _status),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.md,
                        AppSizes.md,
                        AppSizes.md,
                        AppSizes.xl,
                      ),
                      itemCount: state.orders.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.md),
                      itemBuilder: (_, index) {
                        final order = state.orders[index];
                        return _OrderCard(
                          order: order,
                          onTap: () async {
                            await context.push('/orders/${order.id}');
                            if (mounted) _loadOrders(status: _status);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTab {
  final String label;
  final String? status;

  const _OrderTab({
    required this.label,
    this.status,
  });
}

class _OrderTabs extends StatelessWidget {
  final List<_OrderTab> tabs;
  final String? selectedStatus;
  final ValueChanged<String?> onChanged;

  const _OrderTabs({
    required this.tabs,
    required this.selectedStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final isActive = selectedStatus == tab.status;
          return Center(
            child: ChoiceChip(
              selected: isActive,
              label: Text(tab.label),
              onSelected: (_) => onChanged(tab.status),
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF4F4F4),
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final EcommerceOrder order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isEmpty ? null : order.items.first;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 18),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      order.shopName ?? 'Shop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              if (firstItem != null)
                _OrderItemPreview(
                  item: firstItem,
                  currency: order.currency,
                ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderCode} · ${formatOrderDate(order.placedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${order.totalItems} sản phẩm',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  const Text(
                    'Tổng tiền',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatOrderAmount(order.totalAmount, order.currency),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppSizes.fontXl,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderItemPreview extends StatelessWidget {
  final OrderItem item;
  final String currency;

  const _OrderItemPreview({
    required this.item,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                'x${item.qty}',
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
              color: Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
        width: 72,
        height: 72,
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
