import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/place_order_usecase.dart';
import '../../domain/usecases/place_direct_order_usecase.dart';
import 'checkout_event.dart';
import 'checkout_state.dart';

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  final PlaceOrderUseCase placeOrderUseCase;
  final PlaceDirectOrderUseCase placeDirectOrderUseCase;

  CheckoutBloc({
    required this.placeOrderUseCase,
    required this.placeDirectOrderUseCase,
  }) : super(const CheckoutInitial()) {
    on<CheckoutPlaceOrderRequested>(_onPlaceOrderRequested);
    on<CheckoutDirectOrderRequested>(_onDirectOrderRequested);
  }

  Future<void> _onPlaceOrderRequested(
    CheckoutPlaceOrderRequested event,
    Emitter<CheckoutState> emit,
  ) async {
    emit(const CheckoutSubmitting());
    final result = await placeOrderUseCase(
      address: event.address,
      note: event.note,
      discountAmount: event.discountAmount,
    );

    result.fold(
      (failure) => emit(CheckoutFailure(failure.message)),
      (checkoutResult) => emit(CheckoutSuccess(checkoutResult)),
    );
  }

  Future<void> _onDirectOrderRequested(
    CheckoutDirectOrderRequested event,
    Emitter<CheckoutState> emit,
  ) async {
    emit(const CheckoutSubmitting());
    final result = await placeDirectOrderUseCase(
      address: event.address,
      productId: event.productId,
      variantId: event.variantId,
      qty: event.qty,
      note: event.note,
      discountAmount: event.discountAmount,
    );

    result.fold(
      (failure) => emit(CheckoutFailure(failure.message)),
      (checkoutResult) => emit(CheckoutSuccess(checkoutResult)),
    );
  }
}
