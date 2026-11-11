import '../../domain/entities/order_tracking_event.dart';

class OrderTrackingEventModel {
  final String id;
  final String orderId;
  final String status;
  final String title;
  final String? description;
  final String? location;
  final String? carrierName;
  final double? lat;
  final double? lng;
  final String actorRole;
  final DateTime? createdAt;

  const OrderTrackingEventModel({
    required this.id,
    required this.orderId,
    required this.status,
    required this.title,
    this.description,
    this.location,
    this.carrierName,
    this.lat,
    this.lng,
    this.actorRole = 'system',
    this.createdAt,
  });

  factory OrderTrackingEventModel.fromJson(Map<String, dynamic> json) {
    return OrderTrackingEventModel(
      id: (json['id'] as String?) ?? '',
      orderId: (json['order_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'in_transit',
      title: (json['title'] as String?) ?? 'Cập nhật vận chuyển',
      description: json['description'] as String?,
      location: json['location'] as String?,
      carrierName: json['carrier_name'] as String?,
      lat: _asDoubleOrNull(json['lat']),
      lng: _asDoubleOrNull(json['lng']),
      actorRole: (json['actor_role'] as String?) ?? 'system',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  OrderTrackingEvent toEntity() {
    return OrderTrackingEvent(
      id: id,
      orderId: orderId,
      status: status,
      title: title,
      description: description,
      location: location,
      carrierName: carrierName,
      lat: lat,
      lng: lng,
      actorRole: actorRole,
      createdAt: createdAt,
    );
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

