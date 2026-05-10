    import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/routes/admin_router.dart';
import '../screen/admin_login_screen.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const AdminLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C), // Premium deep dark sidebar
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Sidebar Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6200EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHARECO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            AdminSession.loggedInRole == 'admin' ? 'Super Admin 👑' : 'Nhãn Hàng 🏷️',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                // Sidebar Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (AdminSession.loggedInRole == 'admin') ...[
                        _buildMenuItem(
                          context: context,
                          icon: Icons.storefront_rounded,
                          label: 'Nhãn hàng / Shops',
                          route: AdminRouter.shops,
                          isActive: currentRoute == AdminRouter.shops,
                        ),
                        const SizedBox(height: 8),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.inventory_2_rounded,
                          label: 'Tất cả sản phẩm',
                          route: AdminRouter.products,
                          isActive: currentRoute.startsWith(AdminRouter.products),
                        ),
                        const SizedBox(height: 8),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Tất cả đơn hàng',
                          route: AdminRouter.orders,
                          isActive: currentRoute == AdminRouter.orders,
                        ),
                      ] else ...[
                        _buildMenuItem(
                          context: context,
                          icon: Icons.inventory_2_rounded,
                          label: 'Sản phẩm của tôi',
                          route: AdminRouter.products,
                          isActive: currentRoute.startsWith(AdminRouter.products),
                        ),
                        const SizedBox(height: 8),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Đơn hàng của tôi',
                          route: AdminRouter.orders,
                          isActive: currentRoute == AdminRouter.orders,
                        ),
                      ],
                    ],
                  ),
                ),
                // Sidebar Footer (Logged in profile info)
                const Divider(color: Colors.white10, height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF6200EE),
                        child: Text(
                          (AdminSession.loggedInShopName ?? 'A')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AdminSession.loggedInShopName ?? 'Platform Admin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              AdminSession.loggedInEmail ?? 'admin@shareco.vn',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                        onPressed: () {
                          // Clear session and go to login
                          AdminSession.loggedInRole = null;
                          AdminSession.loggedInShopId = null;
                          AdminSession.loggedInShopName = null;
                          AdminSession.loggedInEmail = null;
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã đăng xuất hệ thống!')),
                          );
                          context.go(AdminRouter.login);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Body Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Header
                Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E1E2C),
                        ),
                      ),
                      Row(
                        children: [
                          // Status Indicators
                          _buildIndicator(
                            color: Colors.green,
                            text: 'Kết nối Supabase Live',
                          ),
                          const SizedBox(width: 24),
                          // Notification
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.notifications_none_rounded, color: Colors.grey[700]),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Main Scrollable Area
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8F9FA), // Soft modern background grey
                    padding: const EdgeInsets.all(32),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6200EE).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? const Border(
                  left: BorderSide(color: Color(0xFF6200EE), width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF8C52FF) : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
