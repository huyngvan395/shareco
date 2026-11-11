import 'package:equatable/equatable.dart';

abstract class OrderDetailEvent extends Equatable {
  const OrderDetailEvent();

  @override
  List<Object?> get props => [];
}

class OrderDetailRequested extends OrderDetailEvent {
  final String orderId;

  const OrderDetailRequested(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class OrderCancelRequested extends OrderDetailEvent {
  final String orderId;
  final String? reason;

  const OrderCancelRequested(this.orderId, {this.reason});

  @override
  List<Object?> get props => [orderId, reason];
}

class OrderConfirmDeliveredRequested extends OrderDetailEvent {
  final String orderId;

  const OrderConfirmDeliveredRequested(this.orderId);

  @override
  List<Object?> get props => [orderId];
}
