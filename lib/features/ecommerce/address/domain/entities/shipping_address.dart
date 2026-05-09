import 'package:equatable/equatable.dart';

import '../../../checkout/domain/entities/checkout_address.dart';

class ShippingAddress extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String? province;
  final String? district;
  final String? ward;
  final String addressLine;
  final String? postalCode;
  final bool isDefault;
  final DateTime? createdAt;

  const ShippingAddress({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    this.province,
    this.district,
    this.ward,
    required this.addressLine,
    this.postalCode,
    required this.isDefault,
    this.createdAt,
  });

  CheckoutAddress toCheckoutAddress({String? paymentMethod}) {
    return CheckoutAddress(
      fullName: fullName,
      phone: phone,
      province: province,
      district: district,
      ward: ward,
      addressLine: addressLine,
      postalCode: postalCode,
      paymentMethod: paymentMethod,
    );
  }

  String get locationText {
    return [
      ward,
      district,
      province,
    ].where((value) => value != null && value.trim().isNotEmpty).join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        phone,
        province,
        district,
        ward,
        addressLine,
        postalCode,
        isDefault,
        createdAt,
      ];
}
