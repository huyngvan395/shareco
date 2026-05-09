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

  const OrderCancelRequested(this.orderId);

  @override
  List<Object?> get props => [orderId];
}
