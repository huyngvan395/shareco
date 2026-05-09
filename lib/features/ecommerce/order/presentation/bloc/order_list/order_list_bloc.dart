import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_orders_usecase.dart';
import 'order_list_event.dart';
import 'order_list_state.dart';

class OrderListBloc extends Bloc<OrderListEvent, OrderListState> {
  final GetOrdersUseCase getOrdersUseCase;

  OrderListBloc({required this.getOrdersUseCase})
      : super(const OrderListInitial()) {
    on<OrderListRequested>(_onRequested);
  }

  Future<void> _onRequested(
    OrderListRequested event,
    Emitter<OrderListState> emit,
  ) async {
    emit(OrderListLoading(status: event.status));
    final result = await getOrdersUseCase(status: event.status);
    result.fold(
      (failure) => emit(OrderListFailure(failure.message, status: event.status)),
      (orders) => emit(OrderListLoaded(orders: orders, status: event.status)),
    );
  }
}
