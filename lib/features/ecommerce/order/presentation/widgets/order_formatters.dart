import 'package:intl/intl.dart';

String formatOrderAmount(double amount, String currency) {
  final formatter = NumberFormat.decimalPattern('vi_VN');
  return '${formatter.format(amount)} $currency';
}

String formatOrderDate(DateTime? value) {
  if (value == null) return '--';
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}
