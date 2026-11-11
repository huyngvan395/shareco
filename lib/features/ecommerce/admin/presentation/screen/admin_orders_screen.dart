import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/order_tracking_event.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';
import 'admin_login_screen.dart';

const List<String> kAdminSupportedCarriers = [
  'SPX Express',
  'Giao Hàng Nhanh (GHN)',
  'J&T Express',
  'Viettel Post',
  'Giao Hàng Tiết Kiệm (GHTK)',
  'Ninja Van',
  'GrabExpress (Hỏa tốc)',
];

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';
  bool _showCharts = true;

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
              .where((o) =>
                  o.status == 'pending' ||
                  o.status == 'paid' ||
                  o.status == 'confirmed' ||
                  o.status == 'packed')
              .length;
          final completedCount = allOrders
              .where((o) => o.status == 'completed' || o.status == 'shipping')
              .length;

          final filteredOrders = allOrders.where((o) {
            final q = _searchQuery.trim().toLowerCase();
            final recipient = (o.addressSnapshot['recipient_name'] ??
                    o.addressSnapshot['full_name'] ??
                    o.addressSnapshot['name'] ??
                    '')
                .toString()
                .toLowerCase();
            final phone = (o.addressSnapshot['phone'] ??
                    o.addressSnapshot['phone_number'] ??
                    '')
                .toString()
                .toLowerCase();
            final tracking = (o.trackingCode ?? '').toLowerCase();
            final matchesSearch = q.isEmpty ||
                o.orderCode.toLowerCase().contains(q) ||
                recipient.contains(q) ||
                phone.contains(q) ||
                tracking.contains(q);

            if (!matchesSearch) return false;
            if (_filterStatus == 'all') return true;
            if (_filterStatus == 'pending') {
              return o.status == 'pending' || o.status == 'paid';
            }
            if (_filterStatus == 'packed') {
              return o.status == 'packed' || o.status == 'confirmed';
            }
            return o.status == _filterStatus;
          }).toList();

          return AdminLayout(
            title: AdminSession.loggedInRole == 'shop'
                ? 'Kênh Người Bán • Vận Hành Đơn Hàng'
                : 'Quản Lý Vận Đơn Toàn Hệ Thống',
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. KPI Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: AdminKpiCard(
                          title: 'Tổng Đơn Hàng',
                          value: '${allOrders.length}',
                          subtitle: AdminSession.loggedInRole == 'shop'
                              ? 'Đơn khách đã đặt tại shop'
                              : 'Đơn đặt trên sàn',
                          icon: Icons.receipt_long_rounded,
                          color: AdminPalette.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AdminKpiCard(
                          title: 'Doanh Thu (GMV)',
                          value: AdminFormatters.formatVnd(totalRevenue),
                          subtitle: 'Không tính đơn đã hủy',
                          icon: Icons.payments_rounded,
                          color: AdminPalette.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AdminKpiCard(
                          title: 'Cần Đóng Gói / Giao ĐVVC',
                          value: '$pendingCount',
                          subtitle: 'Cần người bán xử lý',
                          icon: Icons.pending_actions_rounded,
                          color: AdminPalette.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AdminKpiCard(
                          title: 'Đang Giao & Đã Giao',
                          value: '$completedCount',
                          subtitle: 'Vận chuyển thành công',
                          icon: Icons.local_shipping_rounded,
                          color: AdminPalette.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Visual Analytics Section (Biểu đồ trực quan)
                  _buildVisualAnalyticsSection(allOrders),
                  const SizedBox(height: 18),

                  // 3. Search & Filter Bar
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
                                hintText:
                                    'Tìm theo mã đơn (#SHC...), mã vận đơn, tên người nhận hoặc SĐT...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AdminPalette.textSecondary,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: AdminPalette.textSecondary,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AdminPalette.border),
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
                        _buildFilterPill('Đã gói', 'packed'),
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

                  // 4. Main Orders Table Container
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: state.status == AdminStatus.loading && allOrders.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : filteredOrders.isEmpty
                            ? _buildEmptyState()
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                    headingRowHeight: 52,
                                    dataRowMinHeight: 78,
                                    dataRowMaxHeight: 88,
                                    horizontalMargin: 24,
                                    columnSpacing: 20,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'MÃ ĐƠN & THỜI GIAN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'NGƯỜI NHẬN & ĐỊA CHỈ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'SẢN PHẨM MUA',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'VẬN CHUYỂN & VỊ TRÍ HIỆN TẠI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TỔNG TIỀN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TRẠNG THÁI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'HÀNH ĐỘNG VẬN HÀNH',
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
                                          order.addressSnapshot['full_name'] ??
                                          order.addressSnapshot['name'] ??
                                          'Khách hàng ShareCo';
                                      final phone =
                                          order.addressSnapshot['phone'] ??
                                          order.addressSnapshot['phone_number'] ??
                                          'Chưa cập nhật';
                                      final province =
                                          order.addressSnapshot['province'] ??
                                          order.addressSnapshot['city'] ??
                                          '';
                                      final firstItem = order.items.isNotEmpty
                                          ? order.items.first.title
                                          : 'Đơn hàng sản phẩm';

                                      return DataRow(
                                        cells: [
                                          // 1. Mã đơn
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
                                          // 2. Người nhận
                                          DataCell(
                                            SizedBox(
                                              width: 170,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    recipient.toString(),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: AdminPalette.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$phone • $province',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AdminPalette.textSecondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 3. Sản phẩm
                                          DataCell(
                                            SizedBox(
                                              width: 190,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    firstItem,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12.5,
                                                      color: AdminPalette.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '${order.items.length} phân loại • x${order.totalItems} món',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AdminPalette.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 4. Vận chuyển & vị trí
                                          DataCell(
                                            SizedBox(
                                              width: 210,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.local_shipping_outlined,
                                                        size: 14,
                                                        color: AdminPalette.primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        order.shippingCarrier ?? 'Chưa gán ĐVVC',
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AdminPalette.textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.place_rounded,
                                                        size: 13,
                                                        color: AdminPalette.accent,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Expanded(
                                                        child: Text(
                                                          order.currentLocation ??
                                                              (order.status == 'completed'
                                                                  ? 'Đã giao thành công'
                                                                  : 'Đang chuẩn bị tại kho'),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Color(0xFF475569),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 5. Tổng tiền
                                          DataCell(
                                            Text(
                                              AdminFormatters.formatVnd(order.totalAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AdminPalette.danger,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                          // 6. Trạng thái Dropdown
                                          DataCell(
                                            _buildStatusDropdown(context, order),
                                          ),
                                          // 7. Hành động
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Nút cập nhật vị trí nhanh nếu đơn đang giao
                                                if (order.status == 'shipping') ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _showUpdateLocationModal(context, order),
                                                    icon: const Icon(Icons.my_location_rounded, size: 14),
                                                    label: const Text('Vị trí', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0D9488),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                // Nút đóng gói nhanh nếu đơn chờ
                                                if (order.status == 'pending' || order.status == 'paid') ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _showPackOrderModal(context, order),
                                                    icon: const Icon(Icons.inventory_2_rounded, size: 14),
                                                    label: const Text('Đóng gói', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AdminPalette.warning,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                // Nút bàn giao ĐVVC nếu đã gói
                                                if (order.status == 'packed' || order.status == 'confirmed') ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _showHandoverModal(context, order),
                                                    icon: const Icon(Icons.local_shipping_rounded, size: 14),
                                                    label: const Text('Giao ĐVVC', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AdminPalette.primary,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showOrderDetailsModal(context, order),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AdminPalette.primary,
                                                    side: const BorderSide(
                                                      color: AdminPalette.border,
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 7,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 15,
                                                  ),
                                                  label: const Text(
                                                    'Chi tiết',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. VISUAL ANALYTICS & CHARTS SECTION
  // ─────────────────────────────────────────────────────────────

  Widget _buildVisualAnalyticsSection(List<EcommerceOrder> allOrders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AdminPalette.primaryLight, AdminPalette.accent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biểu Đồ Doanh Thu & Hiệu Suất Vận Hành Gian Hàng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AdminPalette.textPrimary,
                          ),
                        ),
                        Text(
                          AdminSession.loggedInRole == 'shop'
                              ? 'Dữ liệu thời gian thực được tổng hợp theo đơn đặt hàng tại gian hàng'
                              : 'Toàn bộ vận đơn và chỉ số giao vận trên toàn sàn ShareCo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showCharts = !_showCharts),
                  icon: Icon(
                    _showCharts
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AdminPalette.primary,
                  ),
                  label: Text(
                    _showCharts ? 'Thu gọn biểu đồ' : 'Mở rộng biểu đồ',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AdminPalette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCharts) ...[
            const Divider(color: AdminPalette.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biểu đồ Cột Doanh Thu 7 Ngày Gần Nhất
                  Expanded(
                    flex: 13,
                    child: _buildRevenueBarChart(allOrders),
                  ),
                  const SizedBox(width: 22),
                  // Biểu đồ Cơ Cấu Vận Đơn & Tỷ Lệ Giao Hàng
                  Expanded(
                    flex: 11,
                    child: _buildOrderStatusBreakdown(allOrders),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueBarChart(List<EcommerceOrder> orders) {
    // Nhóm doanh thu 7 ngày qua
    final now = DateTime.now();
    final List<Map<String, dynamic>> dailyData = [];

    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final weekdayName = weekdays[(targetDate.weekday - 1) % 7];
      final shortLabel =
          '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}';
      final dayLabel = '$weekdayName, $shortLabel';

      final dayRevenue = orders.where((o) {
        if (o.status == 'cancelled' || o.placedAt == null) return false;
        final d = o.placedAt!.toLocal();
        return d.year == targetDate.year &&
            d.month == targetDate.month &&
            d.day == targetDate.day;
      }).fold<double>(0.0, (sum, o) => sum + o.totalAmount);

      final dayCount = orders.where((o) {
        if (o.placedAt == null) return false;
        final d = o.placedAt!.toLocal();
        return d.year == targetDate.year &&
            d.month == targetDate.month &&
            d.day == targetDate.day;
      }).length;

      dailyData.add({
        'date': targetDate,
        'label': dayLabel,
        'short': shortLabel,
        'revenue': dayRevenue,
        'count': dayCount,
      });
    }

    double maxRev = 0;
    for (final d in dailyData) {
      if ((d['revenue'] as double) > maxRev) {
        maxRev = d['revenue'] as double;
      }
    }
    if (maxRev == 0) maxRev = 1000000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: AdminPalette.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Doanh Thu 7 Ngày Gần Nhất',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AdminPalette.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminPalette.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Cập nhật tự động',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AdminPalette.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyData.map((d) {
                final rev = d['revenue'] as double;
                final heightFactor = (rev / maxRev).clamp(0.08, 1.0);
                final isToday = (d['date'] as DateTime).day == now.day;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge tiền ở đỉnh cột
                      Text(
                        rev == 0 ? '-' : _formatShortCurrency(rev),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: rev > 0 ? AdminPalette.textPrimary : Colors.black26,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Thanh Bar Gradient
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 24,
                        height: 90 * heightFactor,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isToday
                                ? [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]
                                : [
                                    AdminPalette.primaryLight,
                                    AdminPalette.primary,
                                  ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          boxShadow: rev > 0
                              ? [
                                  BoxShadow(
                                    color: AdminPalette.primary.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Nhãn ngày bên dưới
                      Text(
                        isToday ? 'Hôm nay' : (d['short'] as String),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isToday ? AdminPalette.primary : AdminPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusBreakdown(List<EcommerceOrder> orders) {
    final total = orders.isEmpty ? 1 : orders.length;
    final pending = orders.where((o) => o.status == 'pending' || o.status == 'paid').length;
    final packed = orders.where((o) => o.status == 'packed' || o.status == 'confirmed').length;
    final shipping = orders.where((o) => o.status == 'shipping').length;
    final completed = orders.where((o) => o.status == 'completed').length;
    final cancelled = orders.where((o) => o.status == 'cancelled').length;

    final pPending = pending / total;
    final pPacked = packed / total;
    final pShipping = shipping / total;
    final pCompleted = completed / total;
    final pCancelled = cancelled / total;

    final successRate = (completed + shipping) > 0
        ? ((completed / (completed + cancelled + 0.001)) * 100).clamp(0, 100).toStringAsFixed(1)
        : '100.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: AdminPalette.info, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cơ Cấu Vận Đơn & Tỷ Lệ Giao',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AdminPalette.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tỷ lệ giao: $successRate%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AdminPalette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Multi-color Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (pCompleted > 0)
                    Expanded(flex: (pCompleted * 100).toInt().clamp(1, 100), child: Container(color: AdminPalette.success)),
                  if (pShipping > 0)
                    Expanded(flex: (pShipping * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFF0D9488))),
                  if (pPacked > 0)
                    Expanded(flex: (pPacked * 100).toInt().clamp(1, 100), child: Container(color: AdminPalette.info)),
                  if (pPending > 0)
                    Expanded(flex: (pPending * 100).toInt().clamp(1, 100), child: Container(color: AdminPalette.warning)),
                  if (pCancelled > 0)
                    Expanded(flex: (pCancelled * 100).toInt().clamp(1, 100), child: Container(color: AdminPalette.danger)),
                  if (orders.isEmpty)
                    Expanded(child: Container(color: Colors.black12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend Breakdown
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendPill('Hoàn thành', completed, AdminPalette.success),
              _buildLegendPill('Đang giao', shipping, const Color(0xFF0D9488)),
              _buildLegendPill('Đã đóng gói', packed, AdminPalette.info),
              _buildLegendPill('Chờ duyệt', pending, AdminPalette.warning),
              _buildLegendPill('Đã hủy', cancelled, AdminPalette.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: AdminPalette.textSecondary),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AdminPalette.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // ─────────────────────────────────────────────────────────────
  // 2. MODAL CHI TIẾT ĐƠN HÀNG VẬN HÀNH (TIKTOK SHOP STYLE)
  // ─────────────────────────────────────────────────────────────

  void _showOrderDetailsModal(BuildContext context, EcommerceOrder order) {
    final address = order.addressSnapshot;
    final fullAddress = [
      address['line1'] ?? address['address_line'] ?? address['address'],
      address['ward'],
      address['district'],
      address['province'] ?? address['city'],
    ].where((s) => s != null && s.toString().isNotEmpty).join(', ');
    final recipientName = address['recipient_name'] ??
        address['full_name'] ??
        address['name'] ??
        'Khách hàng ShareCo';
    final recipientPhone =
        address['phone'] ?? address['phone_number'] ?? 'Chưa cập nhật';

    final carrier = (order.shippingCarrier ?? '').trim().isNotEmpty
        ? order.shippingCarrier!.trim()
        : 'SPX Express';
    final trackingCode = (order.trackingCode ?? '').trim();

    // Timeline các mốc
    final events = order.trackingEvents.isNotEmpty
        ? order.trackingEvents
        : _buildFallbackTimeline(order);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 20, 14),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AdminPalette.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AdminPalette.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi Tiết Đơn Hàng #${order.orderCode}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      Text(
                        'Đặt lúc: ${AdminFormatters.formatDateTime(order.placedAt)}',
                        style: const TextStyle(fontSize: 12, color: AdminPalette.textSecondary),
                      ),
                    ],
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
            width: 740,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TikTok-Style Delivery Progress Stepper
                  _buildDeliveryStepper(order.status),
                  const SizedBox(height: 18),

                  // 2. Action Buttons Banner (Các thao tác nhanh dành cho Shop)
                  _buildOrderActionButtonsBanner(context, order, ctx),
                  const SizedBox(height: 18),

                  // 3. Thông tin vận chuyển & vị trí hiện tại
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_rounded,
                                  size: 18,
                                  color: AdminPalette.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'HÃNG VẬN CHUYỂN: ${carrier.toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: AdminPalette.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (trackingCode.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: trackingCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã sao chép mã vận đơn: $trackingCode')),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminPalette.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Mã: $trackingCode',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                          color: AdminPalette.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded, size: 13, color: AdminPalette.primary),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: Color(0xFF059669), size: 17),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vị trí hiện tại: ${order.currentLocation ?? (order.status == 'completed' ? 'Đã giao thành công' : 'Đang xử lý tại kho lấy hàng')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. Hành trình di chuyển chi tiết (Timeline Events)
                  const Row(
                    children: [
                      Icon(Icons.route_rounded, size: 16, color: AdminPalette.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'HÀNH TRÌNH VẬN CHUYỂN CHI TIẾT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AdminPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTrackingTimeline(events),
                  const SizedBox(height: 18),

                  // 5. Thông tin Người nhận hàng
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THÔNG TIN NGƯỜI NHẬN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AdminPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$recipientName • SĐT: $recipientPhone',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Địa chỉ: ${fullAddress.isEmpty ? 'Chưa cung cấp' : fullAddress}',
                          style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 12.5),
                        ),
                        if (order.note != null && order.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ghi chú của khách: "${order.note}"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: AdminPalette.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 6. Danh sách sản phẩm
                  const Text(
                    'DANH SÁCH SẢN PHẨM ĐẶT MUA',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AdminPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AdminPalette.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF1F5F9),
                              image: item.imagePath != null
                                  ? DecorationImage(
                                      image: NetworkImage(item.imagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: item.imagePath == null
                                ? const Icon(Icons.shopping_bag_outlined, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Phân loại: ${item.variantName ?? "Tiêu chuẩn"}  •  SL: x${item.qty}',
                                  style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AdminFormatters.formatVnd(item.lineTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AdminPalette.danger,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),

                  // 7. Bảng tổng kết tài chính
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng giá trị đơn hàng:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        AdminFormatters.formatVnd(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
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

  // ─────────────────────────────────────────────────────────────
  // 3. STEPPER & TIMELINE WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildDeliveryStepper(String status) {
    if (status == 'cancelled' || status == 'refunded') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AdminPalette.danger, size: 20),
            SizedBox(width: 8),
            Text(
              'Đơn hàng này đã bị hủy bỏ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AdminPalette.danger,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final int stepIndex;
    switch (status) {
      case 'packed':
      case 'confirmed':
        stepIndex = 1;
        break;
      case 'shipping':
        stepIndex = 2;
        break;
      case 'completed':
        stepIndex = 3;
        break;
      default:
        stepIndex = 0;
    }

    const steps = [
      ('1. Đặt hàng', Icons.receipt_long_rounded),
      ('2. Đóng gói', Icons.inventory_2_rounded),
      ('3. Đang giao', Icons.local_shipping_rounded),
      ('4. Hoàn tất', Icons.check_circle_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminPalette.border),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final lineStep = index ~/ 2;
            final isDone = stepIndex > lineStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isDone ? AdminPalette.primary : const Color(0xFFCBD5E1),
              ),
            );
          }

          final idx = index ~/ 2;
          final (title, icon) = steps[idx];
          final active = stepIndex >= idx;
          final isCurrent = stepIndex == idx;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AdminPalette.primary : const Color(0xFFE2E8F0),
                  border: isCurrent
                      ? Border.all(color: AdminPalette.primaryLight, width: 2.5)
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: active ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AdminPalette.primary : AdminPalette.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOrderActionButtonsBanner(
    BuildContext rootContext,
    EcommerceOrder order,
    BuildContext dialogCtx,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AdminPalette.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'THAO TÁC:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
          const SizedBox(width: 12),
          // Nếu đơn đang giao -> Cho phép cập nhật vị trí
          if (order.status == 'shipping') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showUpdateLocationModal(rootContext, order);
              },
              icon: const Icon(Icons.my_location_rounded, size: 15),
              label: const Text('Cập nhật vị trí đơn hàng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                rootContext.read<AdminBloc>().add(
                      AdminAdvanceOrderLocation(
                        orderId: order.id,
                        stepStatus: 'completed',
                        title: 'Giao hàng thành công',
                        location: 'Đã giao đến người nhận',
                        description: 'Khách hàng đã nhận kiện hàng thành công.',
                      ),
                    );
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Đơn #${order.orderCode} đã giao thành công!')),
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 15),
              label: const Text('Xác nhận đã giao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          // Nếu đơn chờ duyệt / đã thanh toán -> Đóng gói
          if (order.status == 'pending' || order.status == 'paid') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showPackOrderModal(rootContext, order);
              },
              icon: const Icon(Icons.inventory_2_rounded, size: 15),
              label: const Text('Xác nhận & đóng gói'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showCancelOrderModal(rootContext, order);
              },
              icon: const Icon(Icons.cancel_outlined, size: 15),
              label: const Text('Hủy đơn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminPalette.danger,
                side: const BorderSide(color: AdminPalette.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          // Nếu đơn đã đóng gói -> Bàn giao ĐVVC
          if (order.status == 'packed' || order.status == 'confirmed') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showHandoverModal(rootContext, order);
              },
              icon: const Icon(Icons.local_shipping_rounded, size: 15),
              label: const Text('Bàn giao cho ĐVVC'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showCancelOrderModal(rootContext, order);
              },
              icon: const Icon(Icons.cancel_outlined, size: 15),
              label: const Text('Hủy đơn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminPalette.danger,
                side: const BorderSide(color: AdminPalette.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          if (order.status == 'completed') ...[
            const Text(
              'Đơn hàng đã hoàn tất giao dịch.',
              style: TextStyle(color: AdminPalette.success, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(List<OrderTrackingEvent> events) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border),
      ),
      child: Column(
        children: List.generate(events.length, (index) {
          final event = events[index];
          final isFirst = index == 0;
          final isLast = index == events.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột mốc và đường kẻ dọc
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFirst ? AdminPalette.primary : const Color(0xFF94A3B8),
                        border: isFirst
                            ? Border.all(color: AdminPalette.primaryLight, width: 2)
                            : null,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Nội dung mốc
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              event.title,
                              style: TextStyle(
                                fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                                color: isFirst ? AdminPalette.textPrimary : const Color(0xFF475569),
                              ),
                            ),
                            if (event.createdAt != null)
                              Text(
                                AdminFormatters.formatDateTime(event.createdAt),
                                style: const TextStyle(fontSize: 11, color: AdminPalette.textSecondary),
                              ),
                          ],
                        ),
                        if (event.location != null && event.location!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, size: 13, color: AdminPalette.accent),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (event.description != null && event.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            event.description!,
                            style: const TextStyle(fontSize: 11.5, color: AdminPalette.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<OrderTrackingEvent> _buildFallbackTimeline(EcommerceOrder order) {
    final list = <OrderTrackingEvent>[];
    if (order.status == 'completed') {
      list.add(OrderTrackingEvent(
        id: 'fallback-complete',
        orderId: order.id,
        status: 'completed',
        title: 'Giao hàng thành công',
        location: order.currentLocation ?? 'Địa chỉ người nhận',
        description: 'Kiện hàng đã được giao đến tay người mua.',
        actorRole: 'carrier',
        createdAt: order.deliveredAt ?? order.updatedAt ?? DateTime.now(),
      ));
    }
    if (order.status == 'shipping' || order.status == 'completed') {
      list.add(OrderTrackingEvent(
        id: 'fallback-shipping',
        orderId: order.id,
        status: 'shipping',
        title: 'Đang vận chuyển giao hàng',
        location: order.currentLocation ?? 'Kho trung chuyển',
        description: 'Đơn vị vận chuyển đang xử lý và điều phối tuyến giao.',
        actorRole: 'carrier',
        createdAt: order.shippedAt ?? DateTime.now().subtract(const Duration(hours: 4)),
      ));
    }
    if (order.status == 'packed' || order.status == 'shipping' || order.status == 'completed') {
      list.add(OrderTrackingEvent(
        id: 'fallback-pack',
        orderId: order.id,
        status: 'packed',
        title: 'Người bán đã đóng gói hàng',
        location: order.pickupLocation ?? 'Kho người bán',
        description: 'Kiện hàng đã được dán mã vận đơn và chờ bàn giao.',
        actorRole: 'seller',
        createdAt: order.confirmedAt ?? DateTime.now().subtract(const Duration(hours: 8)),
      ));
    }
    list.add(OrderTrackingEvent(
      id: 'fallback-place',
      orderId: order.id,
      status: 'pending',
      title: 'Đơn hàng được đặt thành công',
      location: 'Hệ thống ShareCo',
      description: 'Hệ thống đã ghi nhận đơn đặt hàng của khách.',
      actorRole: 'system',
      createdAt: order.placedAt ?? DateTime.now().subtract(const Duration(hours: 12)),
    ));
    return list;
  }

  // ─────────────────────────────────────────────────────────────
  // 4. ACTION MODALS: CẬP NHẬT VỊ TRÍ, BÀN GIAO, ĐÓNG GÓI, HỦY
  // ─────────────────────────────────────────────────────────────

  void _showUpdateLocationModal(BuildContext context, EcommerceOrder order) {
    final addr = order.addressSnapshot;
    final destProvince = addr['province']?.toString().trim() ?? '';
    final destDistrict = addr['district']?.toString().trim() ?? '';
    final carrier = (order.shippingCarrier ?? 'SPX Express').trim();

    final presets = [
      {
        'status': 'arrived_hub',
        'title': 'Đã đến kho phân loại',
        'location': 'Kho phân loại $carrier - $destProvince',
        'desc': 'Kiện hàng đã được quét nhập kho và đang chờ phân tuyến.',
        'icon': Icons.warehouse_rounded,
      },
      {
        'status': 'in_transit',
        'title': 'Đang trung chuyển liên tỉnh',
        'location': 'Trên tuyến đường đến $destProvince',
        'desc': 'Xe tải chuyên tuyến đang vận chuyển kiện hàng đến bưu cục phát.',
        'icon': Icons.alt_route_rounded,
      },
      {
        'status': 'arrived_hub',
        'title': 'Đã đến bưu cục phát',
        'location': 'Bưu cục $destDistrict, $destProvince',
        'desc': 'Kiện hàng đã tới bưu cục gần địa chỉ giao, chuẩn bị giao hàng.',
        'icon': Icons.markunread_mailbox_rounded,
      },
      {
        'status': 'out_for_delivery',
        'title': 'Shipper đang giao hàng',
        'location': 'Đang giao đến địa chỉ người nhận',
        'desc': 'Shipper đang trên đường liên hệ và giao hàng tận nơi.',
        'icon': Icons.delivery_dining_rounded,
      },
      {
        'status': 'completed',
        'title': 'Giao hàng thành công',
        'location': 'Địa chỉ người nhận',
        'desc': 'Đơn hàng đã được giao thành công đến tay khách hàng.',
        'icon': Icons.verified_rounded,
      },
    ];

    final customLocCtrl = TextEditingController(text: order.currentLocation ?? '');
    final customTitleCtrl = TextEditingController();
    final customDescCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.place_rounded, color: Color(0xFF0D9488), size: 22),
              SizedBox(width: 8),
              Text(
                'Cập Nhật Vị Trí Vận Đơn (Tracking Checkpoint)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn #${order.orderCode} • ĐVVC: $carrier',
                    style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CHỌN MỐC VỊ TRÍ NHANH:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AdminPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...presets.map((p) {
                    final isComplete = p['status'] == 'completed';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(dlgCtx);
                          context.read<AdminBloc>().add(
                                AdminAdvanceOrderLocation(
                                  orderId: order.id,
                                  stepStatus: p['status'] as String,
                                  title: p['title'] as String,
                                  location: p['location'] as String,
                                  description: p['desc'] as String,
                                ),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã cập nhật vị trí: ${p['location']}',
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isComplete
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isComplete
                                  ? const Color(0xFFA7F3D0)
                                  : AdminPalette.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                p['icon'] as IconData,
                                color: isComplete
                                    ? AdminPalette.success
                                    : const Color(0xFF0D9488),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      p['location'] as String,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AdminPalette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 13, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  const Text(
                    'HOẶC NHẬP VỊ TRÍ TÙY CHỈNH:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AdminPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customLocCtrl,
                    decoration: InputDecoration(
                      labelText: 'Địa điểm / Vị trí hiện tại *',
                      hintText: 'VD: Hub Củ Chi, TP. Hồ Chí Minh',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customTitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề thông báo',
                      hintText: 'VD: Rời kho luân chuyển',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customDescCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú mô tả thêm',
                      hintText: 'VD: Kiện hàng đang trên xe trung chuyển',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final loc = customLocCtrl.text.trim();
                if (loc.isEmpty) return;
                Navigator.pop(dlgCtx);
                context.read<AdminBloc>().add(
                      AdminAdvanceOrderLocation(
                        orderId: order.id,
                        stepStatus: 'in_transit',
                        title: customTitleCtrl.text.trim().isEmpty
                            ? 'Cập nhật vị trí đơn hàng'
                            : customTitleCtrl.text.trim(),
                        location: loc,
                        description: customDescCtrl.text.trim(),
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã cập nhật vị trí mới: $loc')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu vị trí mới'),
            ),
          ],
        );
      },
    );
  }

  void _showHandoverModal(BuildContext context, EcommerceOrder order) {
    String carrier = kAdminSupportedCarriers.first;
    final trackingCtrl = TextEditingController(
      text: order.trackingCode ??
          'SHC${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    final hubCtrl = TextEditingController(text: 'Bưu cục gửi hàng');

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: AdminPalette.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Bàn Giao Cho Đơn Vị Vận Chuyển',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn #${order.orderCode} sẽ chuyển sang trạng thái "Đang giao hàng" và khách hàng nhận được mã vận đơn.',
                      style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: carrier,
                      decoration: InputDecoration(
                        labelText: 'Đơn vị vận chuyển',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: kAdminSupportedCarriers
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDState(() => carrier = v ?? carrier),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: trackingCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mã vận đơn (Tracking Code)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hubCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bưu cục nhận / điểm xuất phát',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    context.read<AdminBloc>().add(
                          AdminHandoverOrderToCarrier(
                            orderId: order.id,
                            carrier: carrier,
                            trackingCode: trackingCtrl.text.trim(),
                            pickupHub: hubCtrl.text.trim(),
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã bàn giao đơn #${order.orderCode} cho $carrier')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Xác nhận bàn giao'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPackOrderModal(BuildContext context, EcommerceOrder order) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: AdminPalette.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Xác Nhận & Đóng Gói Hàng',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn #${order.orderCode} • ${order.items.length} phân loại (x${order.totalItems} món).\nKhách hàng sẽ nhận thông báo "Người bán đang chuẩn bị hàng".',
                  style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú đóng gói (tùy chọn)',
                    hintText: 'VD: Đã đóng gói cẩn thận, kèm quà tặng',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dlgCtx);
                context.read<AdminBloc>().add(
                      AdminConfirmAndPackOrder(
                        orderId: order.id,
                        note: noteCtrl.text.trim(),
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã xác nhận & đóng gói đơn #${order.orderCode}')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Xác nhận đóng gói'),
            ),
          ],
        );
      },
    );
  }

  void _showCancelOrderModal(BuildContext context, EcommerceOrder order) {
    const reasons = [
      'Hết hàng / không đủ tồn kho cung cấp',
      'Không liên hệ được với người mua hàng',
      'Địa chỉ nhận hàng không hợp lệ / ngoài vùng phục vụ',
      'Người mua yêu cầu hủy đơn qua tin nhắn',
      'Lý do vận hành khác',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.cancel_rounded, color: AdminPalette.danger, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Xác Nhận Hủy Đơn Hàng',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn #${order.orderCode} sẽ bị hủy và hoàn trả tồn kho tự động cho gian hàng.',
                      style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: InputDecoration(
                        labelText: 'Lý do hủy đơn',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: reasons
                          .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setDState(() => selectedReason = v ?? selectedReason),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Không hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    context.read<AdminBloc>().add(
                          AdminSellerCancelOrder(
                            orderId: order.id,
                            reason: selectedReason,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã hủy đơn #${order.orderCode}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminPalette.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Xác nhận hủy đơn'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. HELPER WIDGETS
  // ─────────────────────────────────────────────────────────────

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
      child: Padding(
        padding: const EdgeInsets.all(40),
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
              'Đơn hàng mới khách đặt từ App sẽ tự động đồng bộ về đây theo thời gian thực.',
              style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, EcommerceOrder order) {
    final statusMap = {
      'pending': {'label': 'Chờ xác nhận', 'color': AdminPalette.warning},
      'paid': {'label': 'Đã thanh toán', 'color': AdminPalette.warning},
      'confirmed': {'label': 'Đã xác nhận', 'color': AdminPalette.info},
      'packed': {'label': 'Đã đóng gói', 'color': AdminPalette.info},
      'shipping': {'label': 'Đang giao hàng', 'color': const Color(0xFF0D9488)},
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
}
