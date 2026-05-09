import 'package:equatable/equatable.dart';

class CheckoutAddress extends Equatable {
  final String fullName;
  final String phone;
  final String? province;
  final String? district;
  final String? ward;
  final String addressLine;
  final String? postalCode;
  final String? paymentMethod;

  const CheckoutAddress({
    required this.fullName,
    required this.phone,
    this.province,
    this.district,
    this.ward,
    required this.addressLine,
    this.postalCode,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      'province': province,
      'district': district,
      'ward': ward,
      'address_line': addressLine,
      'postal_code': postalCode,
      'payment_method': paymentMethod,
    };
  }

  @override
  List<Object?> get props => [
        fullName,
        phone,
        province,
        district,
        ward,
        addressLine,
        postalCode,
        paymentMethod,
      ];
}
