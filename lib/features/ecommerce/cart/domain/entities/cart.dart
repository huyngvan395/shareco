import 'package:equatable/equatable.dart';

import 'cart_item.dart';

class Cart extends Equatable {
  final String id;
  final String userId;
  final DateTime? updatedAt;
  final List<CartItem> items;

  const Cart({
    required this.id,
    required this.userId,
    this.updatedAt,
    this.items = const [],
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  String get currency => items.isEmpty ? 'VND' : items.first.currency;
  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [id, userId, updatedAt, items];
}
