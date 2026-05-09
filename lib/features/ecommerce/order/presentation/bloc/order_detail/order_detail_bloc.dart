import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/ecommerce_order.dart';
import '../../../domain/usecases/cancel_order_usecase.dart';
import '../../../domain/usecases/get_order_detail_usecase.dart';
import 'order_detail_event.dart';
import 'order_detail_state.dart';

class OrderDetailBloc extends Bloc<OrderDetailEvent, OrderDetailState> {
  final GetOrderDetailUseCase getOrderDetailUseCase;
  final CancelOrderUseCase cancelOrderUseCase;

  OrderDetailBloc({
    required this.getOrderDetailUseCase,
    required this.cancelOrderUseCase,
  })
      : super(const OrderDetailInitial()) {
    on<OrderDetailRequested>(_onRequested);
    on<OrderCancelRequested>(_onCancelRequested);
  }

  Future<void> _onRequested(
    OrderDetailRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    emit(const OrderDetailLoading());
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
    if (currentOrder == null || currentOrder.status != 'pending') return;

    emit(OrderDetailCancelling(currentOrder));
    final result = await cancelOrderUseCase(event.orderId);
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

  EcommerceOrder? _orderFromState(OrderDetailState state) {
    if (state is OrderDetailLoaded) return state.order;
    if (state is OrderDetailCancelling) return state.order;
    if (state is OrderDetailCancelSuccess) return state.order;
    if (state is OrderDetailCancelFailure) return state.order;
    return null;
  }
}
