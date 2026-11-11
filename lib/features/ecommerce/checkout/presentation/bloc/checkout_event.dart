import 'package:equatable/equatable.dart';

import '../../domain/entities/checkout_address.dart';

abstract class CheckoutEvent extends Equatable {
  const CheckoutEvent();

  @override
  List<Object?> get props => [];
}

class CheckoutPlaceOrderRequested extends CheckoutEvent {
  final CheckoutAddress address;
  final String? note;
  final double discountAmount;
  final double shippingAmount;
  final String shippingService;
  final String? shippingCarrier;

  const CheckoutPlaceOrderRequested({
    required this.address,
    this.note,
    this.discountAmount = 0.0,
    this.shippingAmount = 0.0,
    this.shippingService = 'fast',
    this.shippingCarrier,
  });

  @override
  List<Object?> get props => [
        address,
        note,
        discountAmount,
        shippingAmount,
        shippingService,
        shippingCarrier,
      ];
}

class CheckoutDirectOrderRequested extends CheckoutEvent {
  final CheckoutAddress address;
  final String productId;
  final String? variantId;
  final int qty;
  final String? note;
  final double discountAmount;
  final double shippingAmount;
  final String shippingService;
  final String? shippingCarrier;

  const CheckoutDirectOrderRequested({
    required this.address,
    required this.productId,
    this.variantId,
    required this.qty,
    this.note,
    this.discountAmount = 0.0,
    this.shippingAmount = 0.0,
    this.shippingService = 'fast',
    this.shippingCarrier,
  });

  @override
  List<Object?> get props => [
        address,
        productId,
        variantId,
        qty,
        note,
        discountAmount,
        shippingAmount,
        shippingService,
        shippingCarrier,
      ];
}
