import 'package:equatable/equatable.dart';

import '../../domain/entities/cart.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartLoading extends CartState {
  const CartLoading();
}

class CartLoaded extends CartState {
  final Cart cart;
  final bool isUpdating;

  const CartLoaded({
    required this.cart,
    this.isUpdating = false,
  });

  @override
  List<Object?> get props => [cart, isUpdating];
}

class CartFailure extends CartState {
  final String message;

  const CartFailure(this.message);

  @override
  List<Object?> get props => [message];
}
