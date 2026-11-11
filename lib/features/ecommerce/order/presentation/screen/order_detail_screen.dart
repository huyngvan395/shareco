import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../../chat/domain/usecases/chat_usecases.dart';
import '../../domain/entities/ecommerce_order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/order_tracking_event.dart';
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
  RealtimeChannel? _trackingChannel;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _bloc = sl<OrderDetailBloc>()..add(OrderDetailRequested(widget.orderId));
    _subscribeRealtimeTracking();
  }

  void _subscribeRealtimeTracking() {
    try {
      final ch = SupabaseService.client
          .channel('order_live_${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (mounted) _reload();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'order_tracking_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (mounted) _reload();
            },
          )
          .subscribe();
      _trackingChannel = ch;
    } catch (_) {
      // Realtime optional if offline
    }
  }

  @override
  void dispose() {
    if (_trackingChannel != null) {
      SupabaseService.client.removeChannel(_trackingChannel!);
      _trackingChannel = null;
    }
    _bloc.close();
    super.dispose();
  }

  void _reload() {
    _bloc.add(OrderDetailRequested(widget.orderId));
  }

  Future<void> _confirmCancel(EcommerceOrder order) async {
    const presetReasons = [
      'Muốn thay đổi địa chỉ hoặc sản phẩm',
      'Thay đổi phương thức thanh toán',
      'Tìm thấy sản phẩm phù hợp hơn',
      'Đặt nhầm số lượng / phân loại',
      'Không còn nhu cầu mua nữa',
    ];
    String selectedReason = presetReasons.first;
    final customCtrl = TextEditingController();
    bool useCustom = false;

    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Chọn lý do hủy đơn hàng',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn #${order.orderCode} sẽ được hủy và hoàn lại tồn kho cho shop.',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ...presetReasons.map((reason) {
                      return RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        title: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: reason,
                        groupValue: useCustom ? '__custom__' : selectedReason,
                        onChanged: (val) {
                          if (val == null) return;
                          setDialogState(() {
                            useCustom = false;
                            selectedReason = val;
                          });
                        },
                      );
                    }),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: const Text(
                        'Lý do khác...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: '__custom__',
                      groupValue: useCustom ? '__custom__' : selectedReason,
                      onChanged: (_) {
                        setDialogState(() => useCustom = true);
                      },
                    ),
                    if (useCustom) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Nhập lý do hủy đơn của bạn...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Giữ đơn hàng'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final finalReason = useCustom
                        ? (customCtrl.text.trim().isEmpty
                            ? 'Người mua yêu cầu hủy đơn'
                            : customCtrl.text.trim())
                        : selectedReason;
                    Navigator.of(dialogCtx).pop(finalReason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xác nhận hủy'),
                ),
              ],
            );
          },
        );
      },
    );

    customCtrl.dispose();

    if (confirmedReason != null && mounted) {
      _bloc.add(OrderCancelRequested(order.id, reason: confirmedReason));
    }
  }

  Future<void> _confirmDelivered(EcommerceOrder order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận đã nhận hàng?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Bạn xác nhận đã nhận đủ sản phẩm từ đơn #${order.orderCode} và hàng hóa nguyên vẹn? '
          'Sau khi xác nhận, tiền thanh toán sẽ được quyết toán cho ${order.shopName ?? 'Shop'} và bạn có thể đánh giá sản phẩm.',
          style: const TextStyle(height: 1.4, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Chưa nhận được'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đã nhận hàng'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      _bloc.add(OrderConfirmDeliveredRequested(order.id));
    }
  }

  Future<void> _contactShop(EcommerceOrder order) async {
    final ownerId = order.shopOwnerId;
    if (ownerId == null || ownerId.isEmpty) {
      if (order.shopId.isNotEmpty) {
        context.push('/shop/${order.shopId}');
      }
      return;
    }

    if (ownerId == SupabaseService.currentUserId) {
      context.push('/seller-center', extra: {'shopId': order.shopId, 'tab': 1});
      return;
    }

    if (_openingChat) return;
    setState(() => _openingChat = true);

    final result = await sl<GetOrCreateShopConversationUseCase>()(
      shopId: order.shopId,
      ownerId: ownerId,
      shopName: order.shopName,
    );
    if (!mounted) return;
    setState(() => _openingChat = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (conversation) {
        context.push('/messages', extra: conversation);
      },
    );
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
            'Chi tiết & Hành trình đơn',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'Làm mới hành trình',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
          ],
        ),
        body: BlocConsumer<OrderDetailBloc, OrderDetailState>(
          listener: (context, state) {
            if (state is OrderDetailCancelFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            if (state is OrderDetailCancelSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hủy đơn hàng và hoàn tồn kho'),
                ),
              );
            }
            if (state is OrderDetailConfirmDeliveryFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            if (state is OrderDetailConfirmDeliverySuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cảm ơn bạn đã xác nhận nhận hàng! Bạn có thể đánh giá sản phẩm ngay.',
                  ),
                  backgroundColor: AppColors.success,
                ),
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

            final currentUid = SupabaseService.currentUserId;
            final isShopOwner =
                order.shopOwnerId != null && order.shopOwnerId == currentUid;
            final isBuyer = order.buyerId == currentUid;

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
                  _DeliveryHeroBanner(order: order),
                  const SizedBox(height: AppSizes.md),
                  if (isShopOwner) ...[
                    _SellerOrderManagementBanner(
                      order: order,
                      onOpenSellerCenter: () async {
                        await context.push(
                          '/seller-center',
                          extra: {'shopId': order.shopId, 'tab': 1},
                        );
                        if (mounted) _reload();
                      },
                    ),
                    const SizedBox(height: AppSizes.md),
                  ],
                  _DeliveryProgressStepper(status: order.status),
                  const SizedBox(height: AppSizes.md),
                  _ShipmentTrackingCard(order: order),
                  const SizedBox(height: AppSizes.md),
                  _ItemsSection(
                    order: order,
                    canReview: isBuyer && order.status == 'completed',
                    onReviewSuccess: _reload,
                  ),
                  const SizedBox(height: AppSizes.md),
                  _AddressSection(order: order),
                  const SizedBox(height: AppSizes.md),
                  _PaymentSection(order: order),
                  const SizedBox(height: AppSizes.md),
                  _OrderActionsSection(
                    order: order,
                    isBuyer: isBuyer,
                    isShopOwner: isShopOwner,
                    isCancelling: state is OrderDetailCancelling,
                    isConfirmingDelivery: state is OrderDetailConfirmingDelivery,
                    openingChat: _openingChat,
                    onCancel: () => _confirmCancel(order),
                    onConfirmDelivered: () => _confirmDelivered(order),
                    onContactShop: () => _contactShop(order),
                    onContinueShopping: () => context.go('/ecommerce'),
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
    if (state is OrderDetailConfirmingDelivery) return state.order;
    if (state is OrderDetailConfirmDeliverySuccess) return state.order;
    if (state is OrderDetailConfirmDeliveryFailure) return state.order;
    return null;
  }
}

class _DeliveryHeroBanner extends StatelessWidget {
  final EcommerceOrder order;

  const _DeliveryHeroBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        order.status == 'cancelled' || order.status == 'refunded';
    final isCompleted = order.status == 'completed';
    final isShipping = order.status == 'shipping';

    final Color bgStart;
    final Color bgEnd;
    final IconData icon;
    final String headline;

    if (isCancelled) {
      bgStart = const Color(0xFFD9383A);
      bgEnd = const Color(0xFFB71C1C);
      icon = Icons.cancel_outlined;
      headline = order.status == 'refunded'
          ? 'Đơn hàng đã được hoàn tiền'
          : 'Đơn hàng đã bị hủy';
    } else if (isCompleted) {
      bgStart = const Color(0xFF0EA960);
      bgEnd = const Color(0xFF0A874D);
      icon = Icons.verified_rounded;
      headline = 'Giao hàng thành công';
    } else if (isShipping) {
      bgStart = const Color(0xFF009688);
      bgEnd = const Color(0xFF00796B);
      icon = Icons.local_shipping_rounded;
      headline = 'Đơn hàng đang trên đường giao đến bạn';
    } else if (order.status == 'packed') {
      bgStart = const Color(0xFFF57C00);
      bgEnd = const Color(0xFFE65100);
      icon = Icons.inventory_2_rounded;
      headline = 'Người bán đã đóng gói xong, chờ bàn giao ĐVVC';
    } else if (order.status == 'paid') {
      bgStart = const Color(0xFF1E88E5);
      bgEnd = const Color(0xFF1565C0);
      icon = Icons.credit_score_rounded;
      headline = 'Đã thanh toán • Chờ người bán xác nhận';
    } else {
      bgStart = AppColors.primary;
      bgEnd = const Color(0xFFD83B1C);
      icon = Icons.hourglass_top_rounded;
      headline = 'Đơn hàng đang chờ người bán xác nhận';
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: bgStart.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order.orderCode} · Đặt lúc ${formatOrderDate(order.placedAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.currentLocation != null &&
              order.currentLocation!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vị trí hiện tại: ${order.currentLocation!.trim()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isCancelled &&
              !isCompleted &&
              order.estimatedDeliveryAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white70,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dự kiến nhận hàng trước ${_formatEtaDate(order.estimatedDeliveryAt!)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (isCompleted && order.deliveredAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Đã giao hoàn tất lúc ${formatOrderDate(order.deliveredAt)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (isCancelled &&
              order.cancelReason != null &&
              order.cancelReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Lý do hủy: ${order.cancelReason!.trim()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEtaDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}

class _SellerOrderManagementBanner extends StatelessWidget {
  final EcommerceOrder order;
  final VoidCallback onOpenSellerCenter;

  const _SellerOrderManagementBanner({
    required this.order,
    required this.onOpenSellerCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn hàng của gian hàng bạn',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Xác nhận đóng gói, bàn giao ĐVVC hoặc cập nhật vị trí đơn trong Kênh Người Bán.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onOpenSellerCenter,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Xử lý đơn',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryProgressStepper extends StatelessWidget {
  final String status;

  const _DeliveryProgressStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled' || status == 'refunded') {
      return const SizedBox.shrink();
    }

    final currentStep = _stepIndexForStatus(status);
    const steps = [
      ('Đã đặt', Icons.receipt_long_rounded),
      ('Đóng gói', Icons.inventory_2_rounded),
      ('Đang giao', Icons.local_shipping_rounded),
      ('Hoàn thành', Icons.check_circle_rounded),
    ];

    return _SectionCard(
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final lineStep = index ~/ 2;
            final completed = currentStep > lineStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                color: completed ? AppColors.primary : const Color(0xFFE5E5E5),
              ),
            );
          }

          final stepIdx = index ~/ 2;
          final (label, icon) = steps[stepIdx];
          final active = currentStep >= stepIdx;
          final isCurrent = currentStep == stepIdx;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.primary : const Color(0xFFF0F0F0),
                  border: isCurrent
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 3,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active ? Colors.white : Colors.black38,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? AppColors.primary : Colors.black45,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  int _stepIndexForStatus(String status) {
    switch (status) {
      case 'packed':
        return 1;
      case 'shipping':
        return 2;
      case 'completed':
        return 3;
      case 'pending':
      case 'paid':
      default:
        return 0;
    }
  }
}

class _ShipmentTrackingCard extends StatelessWidget {
  final EcommerceOrder order;

  const _ShipmentTrackingCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final carrier = (order.shippingCarrier ?? '').trim().isNotEmpty
        ? order.shippingCarrier!.trim()
        : 'SPX Express';
    final serviceLabel = _serviceLabel(order.shippingService);
    final trackingCode = (order.trackingCode ?? '').trim();
    final destination = [
      order.addressSnapshot['district']?.toString().trim() ?? '',
      order.addressSnapshot['province']?.toString().trim() ?? '',
    ].where((s) => s.isNotEmpty).join(', ');
    final pickup = (order.pickupLocation ?? '').trim();

    final timeline = order.trackingEvents.isNotEmpty
        ? order.trackingEvents
        : _buildFallbackEvents(order, carrier, pickup, destination);

    return _SectionCard(
      title: 'Thông tin & Hành trình vận chuyển',
      titleIcon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$carrier ($serviceLabel)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                if (trackingCode.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Mã vận đơn: ',
                        style: TextStyle(color: Colors.black54, fontSize: 12.5),
                      ),
                      Expanded(
                        child: Text(
                          trackingCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: trackingCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã sao chép mã vận đơn $trackingCode',
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Sao chép',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (pickup.isNotEmpty || destination.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pickup.isNotEmpty ? pickup : 'Kho người bán',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          destination.isNotEmpty ? destination : 'Người nhận',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(timeline.length, (index) {
            final event = timeline[index];
            final isFirst = index == 0;
            final isLast = index == timeline.length - 1;
            return _TrackingTimelineTile(
              event: event,
              isCurrent: isFirst,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  String _serviceLabel(String? service) {
    switch (service) {
      case 'express':
        return 'Hỏa tốc';
      case 'standard':
        return 'Tiết kiệm';
      case 'fast':
      default:
        return 'Vận chuyển nhanh';
    }
  }

  List<OrderTrackingEvent> _buildFallbackEvents(
    EcommerceOrder order,
    String carrier,
    String pickup,
    String destination,
  ) {
    final list = <OrderTrackingEvent>[];

    if (order.status == 'completed') {
      list.add(
        OrderTrackingEvent(
          id: 'syn-completed',
          orderId: order.id,
          status: 'completed',
          title: 'Giao hàng thành công',
          description: 'Đơn hàng đã được giao thành công đến người nhận.',
          location: destination.isEmpty ? 'Địa chỉ người nhận' : destination,
          carrierName: carrier,
          createdAt: order.deliveredAt ?? order.updatedAt ?? order.placedAt,
        ),
      );
    }

    if (order.status == 'shipping' || order.status == 'completed') {
      list.add(
        OrderTrackingEvent(
          id: 'syn-shipping',
          orderId: order.id,
          status: 'in_transit',
          title: 'Đơn hàng đã bàn giao cho $carrier',
          description: order.currentLocation?.isNotEmpty == true
              ? 'Vị trí hiện tại: ${order.currentLocation}'
              : 'Kiện hàng đang trên đường vận chuyển.',
          location: order.currentLocation ??
              (pickup.isEmpty ? 'Kho trung chuyển' : pickup),
          carrierName: carrier,
          createdAt: order.shippedAt ?? order.updatedAt ?? order.placedAt,
        ),
      );
    }

    if (order.status == 'packed' ||
        order.status == 'shipping' ||
        order.status == 'completed') {
      list.add(
        OrderTrackingEvent(
          id: 'syn-packed',
          orderId: order.id,
          status: 'packed',
          title: 'Người bán đang chuẩn bị & đóng gói hàng',
          description: '${order.shopName ?? 'Cửa hàng'} đã xác nhận đơn hàng.',
          location: pickup.isEmpty ? 'Kho người bán' : pickup,
          carrierName: carrier,
          createdAt: order.confirmedAt ?? order.placedAt,
        ),
      );
    }

    if (order.status == 'cancelled' || order.status == 'refunded') {
      list.add(
        OrderTrackingEvent(
          id: 'syn-cancelled',
          orderId: order.id,
          status: order.status,
          title: order.status == 'refunded'
              ? 'Đơn hàng đã được hoàn tiền'
              : 'Đơn hàng đã bị hủy',
          description: order.cancelReason ?? 'Đơn hàng không còn hiệu lực.',
          location: pickup.isEmpty ? 'Hệ thống ShareCo' : pickup,
          carrierName: carrier,
          createdAt: order.updatedAt ?? order.placedAt,
        ),
      );
    }

    list.add(
      OrderTrackingEvent(
        id: 'syn-placed',
        orderId: order.id,
        status: order.status == 'paid' ? 'paid' : 'pending',
        title: order.status == 'paid'
            ? 'Đặt hàng & Thanh toán thành công'
            : 'Đơn hàng đã được đặt thành công',
        description:
            'Đơn hàng #${order.orderCode} đã được gửi đến ${order.shopName ?? 'Shop'}.',
        location: pickup.isEmpty ? 'Hệ thống ShareCo' : pickup,
        carrierName: carrier,
        createdAt: order.placedAt,
      ),
    );

    return list;
  }
}

class _TrackingTimelineTile extends StatelessWidget {
  final OrderTrackingEvent event;
  final bool isCurrent;
  final bool isLast;

  const _TrackingTimelineTile({
    required this.event,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelEvent =
        event.status == 'cancelled' || event.status == 'refunded';
    final dotColor = isCancelEvent
        ? AppColors.error
        : (isCurrent
            ? (event.status == 'completed'
                ? AppColors.success
                : const Color(0xFF009688))
            : Colors.black26);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 2),
                Container(
                  width: isCurrent ? 16 : 11,
                  height: isCurrent ? 16 : 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: isCurrent
                        ? Border.all(
                            color: dotColor.withValues(alpha: 0.25),
                            width: 4,
                          )
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFE5E5E5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                      color: isCurrent
                          ? (isCancelEvent
                              ? AppColors.error
                              : const Color(0xFF00796B))
                          : Colors.black87,
                    ),
                  ),
                  if (event.location != null &&
                      event.location!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: isCurrent
                              ? const Color(0xFF00796B)
                              : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? Colors.black87
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.description != null &&
                      event.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    formatOrderDate(event.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  final EcommerceOrder order;
  final bool canReview;
  final VoidCallback? onReviewSuccess;

  const _ItemsSection({
    required this.order,
    required this.canReview,
    this.onReviewSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: order.shopName ?? 'Shop',
      titleIcon: Icons.storefront_outlined,
      onTitleTap: order.shopId.isNotEmpty
          ? () => context.push('/shop/${order.shopId}')
          : null,
      child: Column(
        children: order.items.map((item) {
          return _OrderItemRow(
            item: item,
            currency: order.currency,
            canReview: canReview,
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
    final fullName = _firstNonEmpty(address, ['full_name', 'recipient_name']);
    final phone = _value(address, 'phone');
    final line = _firstNonEmpty(address, ['address_line', 'line1']);
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
            [fullName, phone].where((s) => s.isNotEmpty).join(' · '),
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

  static String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = _value(map, k);
      if (v.isNotEmpty) return v;
    }
    return '';
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

    if (order.note != null) {
      if (order.note!.contains('Tiền mặt (COD)')) return 'Tiền mặt (COD)';
      if (order.note!.contains('Thẻ Visa/Mastercard')) {
        return 'Thẻ Visa/Mastercard';
      }
      if (order.note!.contains('QR Chuyển khoản')) return 'QR Chuyển khoản';
    }
    return 'Tiền mặt (COD)';
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
            label: 'Phí vận chuyển',
            value: order.shippingAmount == 0
                ? 'Miễn phí'
                : formatOrderAmount(order.shippingAmount, order.currency),
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

class _OrderActionsSection extends StatelessWidget {
  final EcommerceOrder order;
  final bool isBuyer;
  final bool isShopOwner;
  final bool isCancelling;
  final bool isConfirmingDelivery;
  final bool openingChat;
  final VoidCallback onCancel;
  final VoidCallback onConfirmDelivered;
  final VoidCallback onContactShop;
  final VoidCallback onContinueShopping;

  const _OrderActionsSection({
    required this.order,
    required this.isBuyer,
    required this.isShopOwner,
    required this.isCancelling,
    required this.isConfirmingDelivery,
    required this.openingChat,
    required this.onCancel,
    required this.onConfirmDelivered,
    required this.onContactShop,
    required this.onContinueShopping,
  });

  @override
  Widget build(BuildContext context) {
    final canBuyerCancel =
        isBuyer && (order.status == 'pending' || order.status == 'paid');
    final canConfirmDelivery =
        isBuyer && !isShopOwner && order.status == 'shipping';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canConfirmDelivery) ...[
          ElevatedButton.icon(
            onPressed: isConfirmingDelivery ? null : onConfirmDelivered,
            icon: isConfirmingDelivery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              isConfirmingDelivery
                  ? 'Đang xác nhận...'
                  : 'Đã nhận được hàng',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (canBuyerCancel) ...[
          OutlinedButton.icon(
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
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            if (!isShopOwner) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openingChat ? null : onContactShop,
                  icon: openingChat
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Liên hệ Shop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFD5D5D5)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onContinueShopping,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Tiếp tục mua sắm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
  final bool canReview;
  final VoidCallback onTap;
  final VoidCallback? onReviewSuccess;

  const _OrderItemRow({
    required this.item,
    required this.currency,
    required this.canReview,
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
                      if (item.variantName != null &&
                          item.variantName!.isNotEmpty)
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
    if (!canReview) return const SizedBox.shrink();

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
  final VoidCallback? onTitleTap;
  final Widget child;

  const _SectionCard({
    this.title,
    this.titleIcon,
    this.onTitleTap,
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
            GestureDetector(
              onTap: onTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
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
                  if (onTitleTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.black45,
                    ),
                ],
              ),
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
