import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';
import 'admin_login_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final currentShopId =
        AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;

    return BlocProvider(
      create: (_) => AdminBloc()..add(AdminFetchOrders(shopId: currentShopId)),
      child: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state.status == AdminStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AdminPalette.danger,
              ),
            );
          }
        },
        builder: (context, state) {
          final allOrders = state.orders;
          final totalRevenue = allOrders
              .where((o) => o.status != 'cancelled')
              .fold<double>(0, (sum, o) => sum + o.totalAmount);
          final pendingCount = allOrders
              .where((o) => o.status == 'pending' || o.status == 'confirmed')
              .length;
          final completedCount = allOrders
              .where((o) => o.status == 'completed' || o.status == 'shipping')
              .length;

          final filteredOrders = allOrders.where((o) {
            final q = _searchQuery.trim().toLowerCase();
            final recipient =
                (o.addressSnapshot['recipient_name'] ?? '').toString().toLowerCase();
            final phone = (o.addressSnapshot['phone'] ?? '').toString().toLowerCase();
            final matchesSearch = q.isEmpty ||
                o.orderCode.toLowerCase().contains(q) ||
                recipient.contains(q) ||
                phone.contains(q);

            if (!matchesSearch) return false;
            if (_filterStatus == 'all') return true;
            return o.status == _filterStatus;
          }).toList();

          return AdminLayout(
            title: AdminSession.loggedInRole == 'shop'
                ? 'Quản Lý Đơn Hàng Khách Đặt'
                : 'Quản Lý Vận Đơn Toàn Hệ Thống',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 4 KPI Summary Cards
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Tổng Đơn Hàng',
                      value: '${allOrders.length}',
                      subtitle: 'Đơn đặt mua trên toàn hệ thống',
                      icon: Icons.receipt_long_rounded,
                      color: AdminPalette.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Tổng Doanh Thu (GMV)',
                      value: AdminFormatters.formatVnd(totalRevenue),
                      subtitle: 'Không tính đơn đã hủy',
                      icon: Icons.payments_rounded,
                      color: AdminPalette.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Chờ Xử Lý / Đóng Gói',
                      value: '$pendingCount',
                      subtitle: 'Cần xác nhận giao vận',
                      icon: Icons.pending_actions_rounded,
                      color: AdminPalette.warning,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đang Giao & Hoàn Tất',
                      value: '$completedCount',
                      subtitle: 'Đơn hàng vận hành thành công',
                      icon: Icons.local_shipping_rounded,
                      color: AdminPalette.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Status Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminPalette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mã đơn hàng (#SHC...), tên người nhận hoặc SĐT...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AdminPalette.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AdminPalette.textSecondary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AdminPalette.border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    _buildFilterPill('Tất cả (${allOrders.length})', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Chờ duyệt', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Đang giao', 'shipping'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Hoàn thành', 'completed'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Đã hủy', 'cancelled'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Orders Table
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: state.status == AdminStatus.loading && allOrders.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filteredOrders.isEmpty
                          ? _buildEmptyState()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                    headingRowHeight: 50,
                                    dataRowMinHeight: 74,
                                    dataRowMaxHeight: 82,
                                    horizontalMargin: 24,
                                    columnSpacing: 22,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'MÃ ĐƠN HÀNG',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'KHÁCH HÀNG & LIÊN HỆ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'SẢN PHẨM ĐẶT MUA',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TỔNG THANH TOÁN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TRẠNG THÁI VẬN ĐƠN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'CHI TIẾT',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: filteredOrders.map((order) {
                                      final recipient =
                                          order.addressSnapshot['recipient_name'] ??
                                              'Khách hàng ShareCo';
                                      final phone =
                                          order.addressSnapshot['phone'] ?? 'Chưa cập nhật';
                                      final firstItem = order.items.isNotEmpty
                                          ? order.items.first.title
                                          : 'Đơn hàng sản phẩm';

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AdminPalette.primary
                                                        .withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '#${order.orderCode}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: AdminPalette.primary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  AdminFormatters.formatDateTime(
                                                    order.placedAt,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AdminPalette.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  recipient.toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                    color: AdminPalette.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  phone.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AdminPalette.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 230,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    firstItem,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: AdminPalette.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Tổng: ${order.items.length} mặt hàng',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AdminPalette.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              AdminFormatters.formatVnd(order.totalAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AdminPalette.danger,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            _buildStatusDropdown(context, order),
                                          ),
                                          DataCell(
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showOrderDetailsModal(context, order),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AdminPalette.primary,
                                                side: const BorderSide(
                                                  color: AdminPalette.border,
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Xem đơn',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final selected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AdminPalette.primary.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AdminPalette.primary : AdminPalette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AdminPalette.primary : AdminPalette.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có đơn hàng nào trong danh mục này',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đơn hàng mới khách đặt từ App sẽ tự động đồng bộ về đây.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, EcommerceOrder order) {
    final statusMap = {
      'pending': {'label': 'Chờ xác nhận', 'color': AdminPalette.warning},
      'confirmed': {'label': 'Đã xác nhận', 'color': AdminPalette.info},
      'shipping': {'label': 'Đang giao hàng', 'color': AdminPalette.accent},
      'completed': {'label': 'Hoàn thành', 'color': AdminPalette.success},
      'cancelled': {'label': 'Đã hủy', 'color': AdminPalette.danger},
    };

    final currentStatus =
        statusMap.containsKey(order.status) ? order.status : 'pending';
    final color = statusMap[currentStatus]!['color'] as Color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 18),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          items: statusMap.entries.map((entry) {
            final itemColor = entry.value['color'] as Color;
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value['label'] as String,
                style: TextStyle(
                  color: itemColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != currentStatus) {
              context.read<AdminBloc>().add(
                    AdminUpdateOrderStatus(
                      orderId: order.id,
                      status: newStatus,
                    ),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã cập nhật đơn #${order.orderCode} sang "${statusMap[newStatus]!['label']}"',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showOrderDetailsModal(BuildContext context, EcommerceOrder order) {
    final address = order.addressSnapshot;
    final fullAddress = [
      address['line1'],
      address['ward'],
      address['district'],
      address['province'],
    ].where((s) => s != null && s.toString().isNotEmpty).join(', ');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AdminPalette.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AdminPalette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Chi Tiết Đơn Hàng #${order.orderCode}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shipping Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 17,
                              color: AdminPalette.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'THÔNG TIN NGƯỜI NHẬN HÀNG',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AdminPalette.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Người nhận: ${address['recipient_name'] ?? 'N/A'}  •  SĐT: ${address['phone'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Địa chỉ giao: ${fullAddress.isEmpty ? 'Chưa cung cấp' : fullAddress}',
                          style: const TextStyle(
                            color: AdminPalette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (order.note != null && order.note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ghi chú: "${order.note}"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: AdminPalette.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'DANH SÁCH SẢN PHẨM ĐẶT MUA',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AdminPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...order.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AdminPalette.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF1F5F9),
                              image: item.imagePath != null
                                  ? DecorationImage(
                                      image: NetworkImage(item.imagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: item.imagePath == null
                                ? const Icon(Icons.shopping_bag_outlined)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Phân loại: ${item.variantName ?? 'Tiêu chuẩn'}  •  SL: x${item.qty}',
                                  style: const TextStyle(
                                    color: AdminPalette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AdminFormatters.formatVnd(item.lineTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AdminPalette.danger,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng giá trị thanh toán:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        AdminFormatters.formatVnd(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AdminPalette.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
}
