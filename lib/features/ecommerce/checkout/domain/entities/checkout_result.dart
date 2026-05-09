import 'package:equatable/equatable.dart';

class CheckoutResult extends Equatable {
  final List<String> orderIds;
  final List<String> orderCodes;
  final double totalAmount;
  final String currency;

  const CheckoutResult({
    required this.orderIds,
    required this.orderCodes,
    required this.totalAmount,
    required this.currency,
  });

  @override
  List<Object?> get props => [orderIds, orderCodes, totalAmount, currency];
}
