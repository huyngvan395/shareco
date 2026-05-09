import 'package:equatable/equatable.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class CartRequested extends CartEvent {
  const CartRequested();
}

class CartItemQtyChanged extends CartEvent {
  final String itemId;
  final int qty;

  const CartItemQtyChanged({
    required this.itemId,
    required this.qty,
  });

  @override
  List<Object?> get props => [itemId, qty];
}

class CartItemRemoved extends CartEvent {
  final String itemId;

  const CartItemRemoved(this.itemId);

  @override
  List<Object?> get props => [itemId];
}
