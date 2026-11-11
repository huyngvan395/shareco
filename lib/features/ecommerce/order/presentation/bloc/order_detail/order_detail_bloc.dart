import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/ecommerce_order.dart';
import '../../../domain/usecases/cancel_order_usecase.dart';
import '../../../domain/usecases/confirm_order_delivered_usecase.dart';
import '../../../domain/usecases/get_order_detail_usecase.dart';
import 'order_detail_event.dart';
import 'order_detail_state.dart';

class OrderDetailBloc extends Bloc<OrderDetailEvent, OrderDetailState> {
  final GetOrderDetailUseCase getOrderDetailUseCase;
  final CancelOrderUseCase cancelOrderUseCase;
  final ConfirmOrderDeliveredUseCase confirmOrderDeliveredUseCase;

  OrderDetailBloc({
    required this.getOrderDetailUseCase,
    required this.cancelOrderUseCase,
    required this.confirmOrderDeliveredUseCase,
  }) : super(const OrderDetailInitial()) {
    on<OrderDetailRequested>(_onRequested);
    on<OrderCancelRequested>(_onCancelRequested);
    on<OrderConfirmDeliveredRequested>(_onConfirmDeliveredRequested);
  }

  Future<void> _onRequested(
    OrderDetailRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    if (state is OrderDetailInitial || state is OrderDetailFailure) {
      emit(const OrderDetailLoading());
    }
    final result = await getOrderDetailUseCase(event.orderId);
    result.fold(
      (failure) => emit(OrderDetailFailure(failure.message)),
      (order) => emit(OrderDetailLoaded(order)),
    );
  }

  Future<void> _onCancelRequested(
    OrderCancelRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    final currentOrder = _orderFromState(state);
    if (currentOrder == null ||
        (currentOrder.status != 'pending' && currentOrder.status != 'paid')) {
      return;
    }

    emit(OrderDetailCancelling(currentOrder));
    final result = await cancelOrderUseCase(
      event.orderId,
      reason: event.reason,
    );
    result.fold(
      (failure) => emit(
        OrderDetailCancelFailure(
          order: currentOrder,
          message: failure.message,
        ),
      ),
      (order) => emit(OrderDetailCancelSuccess(order)),
    );
  }

  Future<void> _onConfirmDeliveredRequested(
    OrderConfirmDeliveredRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    final currentOrder = _orderFromState(state);
    if (currentOrder == null || currentOrder.status != 'shipping') return;

    emit(OrderDetailConfirmingDelivery(currentOrder));
    final result = await confirmOrderDeliveredUseCase(event.orderId);
    result.fold(
      (failure) => emit(
        OrderDetailConfirmDeliveryFailure(
          order: currentOrder,
          message: failure.message,
        ),
      ),
      (order) => emit(OrderDetailConfirmDeliverySuccess(order)),
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
