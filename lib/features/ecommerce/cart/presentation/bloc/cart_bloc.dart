import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_cart_usecase.dart';
import '../../domain/usecases/remove_cart_item_usecase.dart';
import '../../domain/usecases/update_cart_item_qty_usecase.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final GetCartUseCase getCartUseCase;
  final UpdateCartItemQtyUseCase updateCartItemQtyUseCase;
  final RemoveCartItemUseCase removeCartItemUseCase;

  CartBloc({
    required this.getCartUseCase,
    required this.updateCartItemQtyUseCase,
    required this.removeCartItemUseCase,
  }) : super(const CartInitial()) {
    on<CartRequested>(_onRequested);
    on<CartItemQtyChanged>(_onQtyChanged);
    on<CartItemRemoved>(_onRemoved);
  }

  Future<void> _onRequested(
    CartRequested event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());
    final result = await getCartUseCase();
    result.fold(
      (failure) => emit(CartFailure(failure.message)),
      (cart) => emit(CartLoaded(cart: cart)),
    );
  }

  Future<void> _onQtyChanged(
    CartItemQtyChanged event,
    Emitter<CartState> emit,
  ) async {
    final current = state;
    if (current is CartLoaded) {
      emit(CartLoaded(cart: current.cart, isUpdating: true));
    }

    final result = await updateCartItemQtyUseCase(
      itemId: event.itemId,
      qty: event.qty,
    );
    result.fold(
      (failure) => emit(CartFailure(failure.message)),
      (cart) => emit(CartLoaded(cart: cart)),
    );
  }

  Future<void> _onRemoved(
    CartItemRemoved event,
    Emitter<CartState> emit,
  ) async {
    final current = state;
    if (current is CartLoaded) {
      emit(CartLoaded(cart: current.cart, isUpdating: true));
    }

    final result = await removeCartItemUseCase(event.itemId);
    result.fold(
      (failure) => emit(CartFailure(failure.message)),
      (cart) => emit(CartLoaded(cart: cart)),
    );
  }
}
