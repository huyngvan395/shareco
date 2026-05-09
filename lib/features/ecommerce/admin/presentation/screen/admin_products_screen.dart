import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_layout.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_bloc.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_event.dart';
import 'package:shareco/features/ecommerce/admin/presentation/bloc/admin_state.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  String? _selectedShopId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc()
        ..add(AdminFetchShops())
        ..add(AdminFetchProducts()),
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
            title: 'Quản lý Hàng hóa & Sản phẩm 📦',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter & Action bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Filter Dropdown
                    Row(
                      children: [
                        const Text(
                          'Lọc theo Nhãn hàng: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedShopId,
                              hint: const Text('Tất cả nhãn hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              onChanged: (val) {
                                setState(() {
                                  _selectedShopId = val;
                                });
                                context.read<AdminBloc>().add(AdminFetchProducts(shopId: val));
                              },
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tất cả nhãn hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                                ...state.shops.map((shop) {
                                  return DropdownMenuItem<String?>(
                                    value: shop['id'],
                                    child: Text(shop['shop_name'] ?? 'Shop', style: const TextStyle(fontSize: 13)),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Add Product button
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/products/new');
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Đăng sản phẩm mới', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Products List
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: state.status == AdminStatus.loading
                          ? const Center(child: CircularProgressIndicator())
                          : state.products.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Không tìm thấy sản phẩm nào.',
                                    style: TextStyle(color: Colors.black45, fontSize: 16),
                                  ),
                                )
                              : ListView(
                                  children: [
                                    _buildProductsTableHeader(),
                                    const Divider(),
                                    ...state.products.map((p) => _buildProductRow(context, p)),
                                  ],
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

  Widget _buildProductsTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 2, child: Text('THƯƠNG HIỆU / SHOP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 2, child: Text('ĐƠN GIÁ (VND)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 1, child: Text('TỒN KHO', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 1, child: Text('TRẠNG THÁI', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
          Expanded(flex: 1, child: Text('THAO TÁC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, Product p) {
    final formattedPrice = p.priceMin.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1))),
      ),
      child: Row(
        children: [
          // Product Thumbnail + Title
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    p.coverPath ?? 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=100',
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${p.id.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Brand/Shop owner
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.store, color: Color(0xFF6200EE), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.shopName ?? 'Nhãn hàng',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Price
          Expanded(
            flex: 2,
            child: Text(
              '$formattedPriceđ',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.red),
            ),
          ),
          // Stock
          Expanded(
            flex: 1,
            child: Text(
              '${p.stockTotal} chiếc',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: p.stockTotal > 5 ? Colors.black54 : Colors.orange.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: p.isActive ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                p.isActive ? 'Đang bán' : 'Ẩn/Ngừng',
                style: TextStyle(
                  color: p.isActive ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Action buttons
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                  onPressed: () {
                    context.go('/products/${p.id}/edit');
                  },
                ),
                // Deactivate / Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () {
                    _showDeleteConfirmDialog(context, p);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext parentContext, Product p) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận ẩn sản phẩm ⚠️'),
          content: Text('Bạn có chắc chắn muốn ngừng kinh doanh sản phẩm "${p.title}" này không? Sản phẩm sẽ chuyển về trạng thái ẩn và không xuất hiện trên feed của khách hàng.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                parentContext.read<AdminBloc>().add(AdminDeleteProduct(productId: p.id));
                Navigator.pop(context);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('Đã ngừng bán sản phẩm "${p.title}"'), backgroundColor: Colors.orange),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Xác nhận ngừng bán', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
