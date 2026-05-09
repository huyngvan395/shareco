import '../../domain/entities/shipping_address.dart';

class ShippingAddressModel {
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

  const ShippingAddressModel({
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

  factory ShippingAddressModel.fromJson(Map<String, dynamic> json) {
    return ShippingAddressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      province: json['province'] as String?,
      district: json['district'] as String?,
      ward: json['ward'] as String?,
      addressLine: json['address_line'] as String? ?? '',
      postalCode: json['postal_code'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']),
    );
  }

  ShippingAddress toEntity() {
    return ShippingAddress(
      id: id,
      userId: userId,
      fullName: fullName,
      phone: phone,
      province: province,
      district: district,
      ward: ward,
      addressLine: addressLine,
      postalCode: postalCode,
      isDefault: isDefault,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
