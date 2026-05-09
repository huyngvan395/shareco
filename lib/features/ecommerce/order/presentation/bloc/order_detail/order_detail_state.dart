import 'package:equatable/equatable.dart';

import '../../../domain/entities/ecommerce_order.dart';

abstract class OrderDetailState extends Equatable {
  const OrderDetailState();

  @override
  List<Object?> get props => [];
}

class OrderDetailInitial extends OrderDetailState {
  const OrderDetailInitial();
}

class OrderDetailLoading extends OrderDetailState {
  const OrderDetailLoading();
}

class OrderDetailLoaded extends OrderDetailState {
  final EcommerceOrder order;

  const OrderDetailLoaded(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderDetailCancelling extends OrderDetailState {
  final EcommerceOrder order;

  const OrderDetailCancelling(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderDetailCancelSuccess extends OrderDetailState {
  final EcommerceOrder order;

  const OrderDetailCancelSuccess(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderDetailCancelFailure extends OrderDetailState {
  final EcommerceOrder order;
  final String message;

  const OrderDetailCancelFailure({
    required this.order,
    required this.message,
  });

  @override
  List<Object?> get props => [order, message];
}

class OrderDetailFailure extends OrderDetailState {
  final String message;

  const OrderDetailFailure(this.message);

  @override
  List<Object?> get props => [message];
}
