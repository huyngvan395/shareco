import 'package:equatable/equatable.dart';

import '../../../domain/entities/ecommerce_order.dart';

abstract class OrderListState extends Equatable {
  const OrderListState();

  @override
  List<Object?> get props => [];
}

class OrderListInitial extends OrderListState {
  const OrderListInitial();
}

class OrderListLoading extends OrderListState {
  final String? status;

  const OrderListLoading({this.status});

  @override
  List<Object?> get props => [status];
}

class OrderListLoaded extends OrderListState {
  final List<EcommerceOrder> orders;
  final String? status;

  const OrderListLoaded({
    required this.orders,
    this.status,
  });

  @override
  List<Object?> get props => [orders, status];
}

class OrderListFailure extends OrderListState {
  final String message;
  final String? status;

  const OrderListFailure(this.message, {this.status});

  @override
  List<Object?> get props => [message, status];
}
