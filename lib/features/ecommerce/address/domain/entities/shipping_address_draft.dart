import 'package:equatable/equatable.dart';

class ShippingAddressDraft extends Equatable {
  final String? id;
  final String fullName;
  final String phone;
  final String? province;
  final String? district;
  final String? ward;
  final String addressLine;
  final String? postalCode;
  final bool isDefault;

  const ShippingAddressDraft({
    this.id,
    required this.fullName,
    required this.phone,
    this.province,
    this.district,
    this.ward,
    required this.addressLine,
    this.postalCode,
    required this.isDefault,
  });

  @override
  List<Object?> get props => [
        id,
        fullName,
        phone,
        province,
        district,
        ward,
        addressLine,
        postalCode,
        isDefault,
      ];
}
