import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;

  const OrderStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        orderStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String orderStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Chờ xử lý';
    case 'paid':
      return 'Đã thanh toán';
    case 'packed':
      return 'Đã đóng gói';
    case 'shipping':
      return 'Đang giao';
    case 'completed':
      return 'Hoàn thành';
    case 'cancelled':
      return 'Đã hủy';
    case 'refunded':
      return 'Đã hoàn tiền';
    default:
      return status;
  }
}

Color orderStatusColor(String status) {
  switch (status) {
    case 'completed':
      return AppColors.success;
    case 'cancelled':
    case 'refunded':
      return AppColors.error;
    case 'shipping':
    case 'paid':
      return AppColors.secondary;
    case 'packed':
      return AppColors.warning;
    case 'pending':
    default:
      return AppColors.primary;
  }
}
