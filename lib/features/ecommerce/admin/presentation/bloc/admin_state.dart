import 'package:equatable/equatable.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product.dart';

enum AdminStatus { initial, loading, success, failure }

class AdminState extends Equatable {
  final AdminStatus status;
  final List<Map<String, dynamic>> shops;
  final List<Product> products;
  final List<EcommerceOrder> orders;
  final List<Map<String, dynamic>> videos;
  final List<Map<String, dynamic>> users;
  final String? errorMessage;

  const AdminState({
    this.status = AdminStatus.initial,
    this.shops = const [],
    this.products = const [],
    this.orders = const [],
    this.videos = const [],
    this.users = const [],
    this.errorMessage,
  });

  AdminState copyWith({
    AdminStatus? status,
    List<Map<String, dynamic>>? shops,
    List<Product>? products,
    List<EcommerceOrder>? orders,
    List<Map<String, dynamic>>? videos,
    List<Map<String, dynamic>>? users,
    String? errorMessage,
  }) {
    return AdminState(
      status: status ?? this.status,
      shops: shops ?? this.shops,
      products: products ?? this.products,
      orders: orders ?? this.orders,
      videos: videos ?? this.videos,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, shops, products, orders, videos, users, errorMessage];
}
