import 'package:equatable/equatable.dart';

class OrderTrackingEvent extends Equatable {
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

  const OrderTrackingEvent({
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

  @override
  List<Object?> get props => [
        id,
        orderId,
        status,
        title,
        description,
        location,
        carrierName,
        lat,
        lng,
        actorRole,
        createdAt,
      ];
}

