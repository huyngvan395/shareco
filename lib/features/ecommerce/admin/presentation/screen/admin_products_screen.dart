import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/routes/admin_router.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_ui_helpers.dart';
import 'admin_login_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'low_stock', 'inactive'

  @override
  Widget build(BuildContext context) {
    final currentShopId =
        AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;

    return BlocProvider(
      create: (_) => AdminBloc()
        ..add(AdminFetchShops())
        ..add(AdminFetchProducts(shopId: currentShopId)),
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
          final allProducts = state.products;
          final activeCount =
              allProducts.where((p) => p.status == 'active').length;
          final lowStockCount =
              allProducts.where((p) => p.stockTotal < 10).length;

          final filteredProducts = allProducts.where((p) {
            final q = _searchQuery.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                p.title.toLowerCase().contains(q) ||
                (p.brand ?? '').toLowerCase().contains(q) ||
                (p.shopName ?? '').toLowerCase().contains(q);

            if (!matchesSearch) return false;

            if (_filterStatus == 'active') return p.status == 'active';
            if (_filterStatus == 'low_stock') return p.stockTotal < 10;
            if (_filterStatus == 'inactive') return p.status != 'active';
            return true;
          }).toList();

          return AdminLayout(
            title: AdminSession.loggedInRole == 'shop'
                ? 'Quản Lý Sản Phẩm Gian Hàng'
                : 'Quản Lý Tất Cả Sản Phẩm Trên Sàn',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // KPI Summary Row
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Tổng Sản Phẩm',
                      value: '${allProducts.length}',
                      subtitle: AdminSession.loggedInRole == 'shop'
                          ? 'Thuộc gian hàng của bạn'
                          : 'Toàn bộ sản phẩm trên sàn',
                      icon: Icons.inventory_2_rounded,
                      color: AdminPalette.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Đang Mở Bán',
                      value: '$activeCount',
                      subtitle: 'Hiển thị trên chợ & gắn thẻ Video',
                      icon: Icons.shopping_bag_outlined,
                      color: AdminPalette.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AdminKpiCard(
                      title: 'Sắp Hết Hàng (<10)',
                      value: '$lowStockCount',
                      subtitle: 'Cần bổ sung tồn kho sớm',
                      icon: Icons.warning_amber_rounded,
                      color: AdminPalette.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Toolbar
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
                            hintText: 'Tìm kiếm theo tên sản phẩm, thương hiệu hoặc shop...',
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
                    _buildFilterPill('Tất cả (${allProducts.length})', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Đang bán ($activeCount)', 'active'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Sắp hết ($lowStockCount)', 'low_stock'),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go(AdminRouter.productCreate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_box_rounded, size: 19),
                      label: const Text(
                        'Đăng Sản Phẩm Mới',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Products DataTable Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: state.status == AdminStatus.loading && allProducts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filteredProducts.isEmpty
                          ? _buildEmptyState(context)
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
                                    dataRowMinHeight: 78,
                                    dataRowMaxHeight: 88,
                                    horizontalMargin: 24,
                                    columnSpacing: 22,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'SẢN PHẨM',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'NHÃN HÀNG / SHOP',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'GIÁ BÁN & KHUYẾN MÃI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TỒN KHO / ĐÃ BÁN',
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
                                          'THAO TÁC',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AdminPalette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: filteredProducts.map((product) {
                                      final isActive = product.status == 'active';
                                      final isLowStock = product.stockTotal < 10;
                                      final hasDiscount = product.originalPrice != null &&
                                          product.originalPrice! > product.priceMin;
                                      final discountPercent = hasDiscount
                                          ? (((product.originalPrice! - product.priceMin) /
                                                      product.originalPrice!) *
                                                  100)
                                              .round()
                                          : 0;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: AdminPalette.border,
                                                    ),
                                                    color: const Color(0xFFF1F5F9),
                                                    image: product.coverPath != null
                                                        ? DecorationImage(
                                                            image: NetworkImage(
                                                              product.coverPath!,
                                                            ),
                                                            fit: BoxFit.cover,
                                                          )
                                                        : null,
                                                  ),
                                                  child: product.coverPath == null
                                                      ? const Icon(
                                                          Icons.image_outlined,
                                                          color: AdminPalette.textSecondary,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 14),
                                                SizedBox(
                                                  width: 260,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        product.title,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 13.5,
                                                          color: AdminPalette.textPrimary,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (product.variants.isNotEmpty) ...[
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          '${product.variants.length} phân loại hàng',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: AdminPalette.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AdminPalette.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                product.shopName ??
                                                    product.brand ??
                                                    'Official Store',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AdminPalette.primary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      AdminFormatters.formatVnd(
                                                        product.priceMin,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        color: AdminPalette.danger,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    if (hasDiscount) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AdminPalette.danger
                                                              .withValues(alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '-$discountPercent%',
                                                          style: const TextStyle(
                                                            color: AdminPalette.danger,
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (hasDiscount)
                                                  Text(
                                                    AdminFormatters.formatVnd(
                                                      product.originalPrice!,
                                                    ),
                                                    style: const TextStyle(
                                                      decoration: TextDecoration.lineThrough,
                                                      color: AdminPalette.textSecondary,
                                                      fontSize: 11.5,
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
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isLowStock
                                                          ? Icons.warning_amber_rounded
                                                          : Icons.inventory_rounded,
                                                      size: 14,
                                                      color: isLowStock
                                                          ? AdminPalette.danger
                                                          : AdminPalette.success,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Kho: ${product.stockTotal}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                        color: isLowStock
                                                            ? AdminPalette.danger
                                                            : AdminPalette.textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Đã bán: ${product.soldCount}',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: AdminPalette.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            AdminStatusBadge(
                                              label: isActive ? 'Đang bán' : 'Đã ẩn',
                                              color: isActive
                                                  ? AdminPalette.success
                                                  : AdminPalette.textSecondary,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildActionButton(
                                                  tooltip: 'Chỉnh sửa sản phẩm',
                                                  icon: Icons.edit_outlined,
                                                  color: AdminPalette.primary,
                                                  onTap: () => context.go(
                                                    '/products/${product.id}/edit',
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildActionButton(
                                                  tooltip: isActive
                                                      ? 'Ẩn sản phẩm khỏi chợ'
                                                      : 'Mở bán lại sản phẩm',
                                                  icon: isActive
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                  color: isActive
                                                      ? AdminPalette.warning
                                                      : AdminPalette.success,
                                                  onTap: () {
                                                    final nextStatus =
                                                        isActive ? 'inactive' : 'active';
                                                    context.read<AdminBloc>().add(
                                                          AdminToggleProductStatus(
                                                            productId: product.id,
                                                            status: nextStatus,
                                                          ),
                                                        );
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          nextStatus == 'inactive'
                                                              ? 'Đã ẩn sản phẩm [${product.title}]!'
                                                              : 'Đã mở bán lại [${product.title}]!',
                                                        ),
                                                      ),
                                                    );
                                                  },
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  Widget _buildActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              Icons.inventory_2_outlined,
              size: 48,
              color: AdminPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có sản phẩm nào phù hợp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhấn "Đăng Sản Phẩm Mới" để đưa sản phẩm lên sàn và gắn vào Video.',
            style: TextStyle(color: AdminPalette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
