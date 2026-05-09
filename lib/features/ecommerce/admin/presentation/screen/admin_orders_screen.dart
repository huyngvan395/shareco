import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_layout.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_event.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_state.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc()..add(AdminFetchOrders()),
      child: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state.status == AdminStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return AdminLayout(
            title: 'Quản lý Đơn hàng Toàn hệ thống 🧾',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal Tabs controller
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF6200EE),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF6200EE),
                    indicatorWeight: 3,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'TẤT CẢ'),
                      Tab(text: 'CHỜ XỬ LÝ (PENDING)'),
                      Tab(text: 'ĐANG ĐÓNG GÓI (PROCESSING)'),
                      Tab(text: 'ĐANG GIAO (SHIPPING)'),
                      Tab(text: 'ĐÃ HOÀN THÀNH (COMPLETED)'),
                      Tab(text: 'HOÀN TIỀN (REFUNDED)'),
                      Tab(text: 'ĐÃ HỦY (CANCELLED)'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Orders Display Area
                Expanded(
                  child: state.status == AdminStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOrdersList(context, state.orders, null),
                            _buildOrdersList(context, state.orders, 'pending'),
                            _buildOrdersList(context, state.orders, 'processing'),
                            _buildOrdersList(context, state.orders, 'shipping'),
                            _buildOrdersList(context, state.orders, 'completed'),
                            _buildOrdersList(context, state.orders, 'refunded'),
                            _buildOrdersList(context, state.orders, 'cancelled'),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<EcommerceOrder> orders, String? filterStatus) {
    final filtered = filterStatus == null
        ? orders
        : orders.where((o) => o.status.toLowerCase() == filterStatus.toLowerCase()).toList();

    if (filtered.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'Không tìm thấy đơn hàng nào thuộc bộ lọc này.',
                  style: TextStyle(color: Colors.black45, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final o = filtered[index];
        return _buildOrderCard(context, o);
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, EcommerceOrder o) {
    final formattedTotal = o.totalAmount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );

    final address = o.addressSnapshot;
    final String fullName = address['fullName'] ?? address['full_name'] ?? 'Khách mua';
    final String phone = address['phone'] ?? '';
    final String addressLine = address['addressLine'] ?? address['address_line'] ?? '';
    final String ward = address['ward'] ?? '';
    final String district = address['district'] ?? '';
    final String province = address['province'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Code, Status, Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'MÃ ĐƠN: #${o.orderCode}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6200EE).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        o.shopName ?? 'Gian hàng',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6200EE)),
                      ),
                    ),
                  ],
                ),
                _buildOrderStatusBadge(o.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Row 2: Customer details, address, payment
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer details
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('THÔNG TIN GIAO NHẬN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black38)),
                      const SizedBox(height: 8),
                      Text('$fullName | $phone', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('$addressLine, $ward, $district, $province', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                // Payment Method & Total Price
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HÓA ĐƠN & THANH TOÁN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black38)),
                      const SizedBox(height: 8),
                      Text(
                        'Tổng hóa đơn: $formattedTotalđ',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final paymentMethod = o.addressSnapshot['payment_method'] as String? ?? 'cod';
                        String ptttLabel = 'Thanh toán COD';
                        bool isPaid = false;
                        if (paymentMethod == 'card') {
                          ptttLabel = 'Thẻ Visa/Mastercard';
                          isPaid = true;
                        } else if (paymentMethod == 'qr') {
                          ptttLabel = 'QR Chuyển khoản';
                          isPaid = true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PTTT: $ptttLabel', style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                            if (isPaid) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 12, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ĐÃ THANH TOÁN',
                                      style: TextStyle(color: Colors.green.shade700, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                // Actions Buttons
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => _showOrderDetailsModal(context, o),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          elevation: 0,
                          minimumSize: const Size(120, 36),
                        ),
                        child: const Text('Xem sản phẩm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      _buildStateActionButton(context, o),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    Color bg = Colors.amber.shade50;
    Color border = Colors.amber.shade200;
    Color text = Colors.amber.shade700;
    String label = 'Đang chờ xử lý';

    switch (status.toLowerCase()) {
      case 'processing':
        bg = Colors.orange.shade50;
        border = Colors.orange.shade200;
        text = Colors.orange.shade700;
        label = 'Đang đóng gói';
        break;
      case 'shipping':
        bg = Colors.blue.shade50;
        border = Colors.blue.shade200;
        text = Colors.blue.shade700;
        label = 'Đang vận chuyển';
        break;
      case 'completed':
        bg = Colors.green.shade50;
        border = Colors.green.shade200;
        text = Colors.green.shade700;
        label = 'Đã hoàn thành';
        break;
      case 'refunded':
        bg = Colors.purple.shade50;
        border = Colors.purple.shade200;
        text = Colors.purple.shade700;
        label = 'Đã hoàn tiền';
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        border = Colors.red.shade200;
        text = Colors.red.shade700;
        label = 'Đã hủy đơn';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStateActionButton(BuildContext context, EcommerceOrder o) {
    final status = o.status.toLowerCase();

    if (status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () {
              context.read<AdminBloc>().add(AdminUpdateOrderStatus(orderId: o.id, status: 'processing'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đơn hàng #${o.orderCode} đã được xác nhận và đang đóng gói'), backgroundColor: Colors.orange),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 36),
            ),
            child: const Text('Xác nhận & Đóng gói', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              context.read<AdminBloc>().add(AdminUpdateOrderStatus(orderId: o.id, status: 'cancelled'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đơn hàng #${o.orderCode} đã bị hủy!'), backgroundColor: Colors.red),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(140, 32),
            ),
            child: const Text('Hủy đơn hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    if (status == 'processing') {
      return ElevatedButton(
        onPressed: () {
          context.read<AdminBloc>().add(AdminUpdateOrderStatus(orderId: o.id, status: 'shipping'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đơn hàng #${o.orderCode} đã bàn giao cho đơn vị vận chuyển'), backgroundColor: Colors.blue),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(140, 36),
        ),
        child: const Text('Giao cho shipper', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    if (status == 'shipping') {
      return ElevatedButton(
        onPressed: () {
          context.read<AdminBloc>().add(AdminUpdateOrderStatus(orderId: o.id, status: 'completed'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đơn hàng #${o.orderCode} đã được giao thành công!'), backgroundColor: Colors.green),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(140, 36),
        ),
        child: const Text('Hoàn tất giao hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    if (status == 'completed') {
      return OutlinedButton(
        onPressed: () {
          context.read<AdminBloc>().add(AdminUpdateOrderStatus(orderId: o.id, status: 'refunded'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã cập nhật trạng thái đơn hàng #${o.orderCode} thành Hoàn tiền'), backgroundColor: Colors.purple),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.purple,
          side: const BorderSide(color: Colors.purple),
          minimumSize: const Size(140, 32),
        ),
        child: const Text('Hoàn tiền đơn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    return const SizedBox.shrink();
  }

  void _showOrderDetailsModal(BuildContext parentContext, EcommerceOrder o) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: Text('Chi tiết sản phẩm đặt mua: Đơn #${o.orderCode}', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              itemCount: o.items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = o.items[index];
                final price = item.unitPrice.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]}.',
                    );
                final total = item.lineTotal.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]}.',
                    );

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.imagePath ?? 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=100',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    'Phân loại: ${item.variantName ?? 'Tiêu chuẩn'} | Số lượng: x${item.qty}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$totalđ', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 13)),
                      Text('$priceđ / chiếc', style: const TextStyle(fontSize: 10, color: Colors.black38)),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EE), foregroundColor: Colors.white),
              child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
