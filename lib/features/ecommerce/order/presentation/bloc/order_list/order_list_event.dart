import 'package:equatable/equatable.dart';

abstract class OrderListEvent extends Equatable {
  const OrderListEvent();

  @override
  List<Object?> get props => [];
}

class OrderListRequested extends OrderListEvent {
  final String? status;

  const OrderListRequested({this.status});

  @override
  List<Object?> get props => [status];
}
