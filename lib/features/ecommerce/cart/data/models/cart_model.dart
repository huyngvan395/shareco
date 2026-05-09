import '../../domain/entities/cart.dart';
import 'cart_item_model.dart';

class CartModel {
  final String id;
  final String userId;
  final DateTime? updatedAt;
  final List<CartItemModel> items;

  const CartModel({
    required this.id,
    required this.userId,
    this.updatedAt,
    this.items = const [],
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['cart_items'];
    return CartModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      updatedAt: _parseDate(json['updated_at']),
      items: itemsJson is List
          ? itemsJson
              .whereType<Map<String, dynamic>>()
              .map(CartItemModel.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  Cart toEntity() {
    return Cart(
      id: id,
      userId: userId,
      updatedAt: updatedAt,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
