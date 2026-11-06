import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/routes/admin_router.dart';
import '../bloc/admin_bloc.dart';
import '../screen/admin_login_screen.dart';
import 'admin_ui_helpers.dart';

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
    final isAdmin = AdminSession.loggedInRole == 'admin';

    return Scaffold(
      backgroundColor: AdminPalette.bg,
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 268,
            decoration: const BoxDecoration(
              color: AdminPalette.sidebarBg,
              border: Border(
                right: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AdminPalette.primaryLight, AdminPalette.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AdminPalette.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SHARECO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                                    : const Color(0xFF38BDF8).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin ? 'SUPER ADMIN 👑' : 'SELLER PORTAL 🏷️',
                                style: TextStyle(
                                  color: isAdmin
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFF38BDF8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    'ĐIỀU HƯỚNG QUẢN TRỊ',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                // Sidebar Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    children: [
                      if (isAdmin) ...[
                        _buildMenuItem(
                          context: context,
                          icon: Icons.storefront_rounded,
                          label: 'Nhãn hàng & Đối tác',
                          subtitle: 'Duyệt shop, tích xanh',
                          route: AdminRouter.shops,
                          isActive: currentRoute == AdminRouter.shops,
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.video_collection_rounded,
                          label: 'Kiểm duyệt Video',
                          subtitle: 'Duyệt đăng & chặn vi phạm',
                          route: AdminRouter.videos,
                          isActive: currentRoute == AdminRouter.videos,
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.inventory_2_rounded,
                          label: 'Tất cả sản phẩm',
                          subtitle: 'Kiểm duyệt & tồn kho',
                          route: AdminRouter.products,
                          isActive: currentRoute.startsWith(AdminRouter.products),
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Quản lý đơn hàng',
                          subtitle: 'Theo dõi vận chuyển',
                          route: AdminRouter.orders,
                          isActive: currentRoute == AdminRouter.orders,
                        ),
                      ] else ...[
                        _buildMenuItem(
                          context: context,
                          icon: Icons.inventory_2_rounded,
                          label: 'Sản phẩm của Shop',
                          subtitle: 'Đăng bán & cập nhật kho',
                          route: AdminRouter.products,
                          isActive: currentRoute.startsWith(AdminRouter.products),
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Đơn hàng khách đặt',
                          subtitle: 'Xác nhận & giao hàng',
                          route: AdminRouter.orders,
                          isActive: currentRoute == AdminRouter.orders,
                        ),
                      ],
                    ],
                  ),
                ),

                // Quick Add Product CTA in Sidebar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    onTap: () => context.go(AdminRouter.productCreate),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AdminPalette.primary.withValues(alpha: 0.25),
                            AdminPalette.accent.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AdminPalette.primaryLight.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_rounded, color: Color(0xFFA5B4FC), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Đăng sản phẩm mới',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sidebar Footer (Logged in profile info)
                const Divider(color: Color(0xFF1E293B), height: 1),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0B1120),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AdminPalette.primaryLight, AdminPalette.accent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Builder(
                          builder: (_) {
                            final name = (AdminSession.loggedInShopName ?? '').trim();
                            final initial =
                                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A';
                            return Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            );
                          },
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
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AdminSession.loggedInEmail ?? 'admin@shareco.vn',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Đăng xuất tài khoản',
                        child: IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFF94A3B8),
                            size: 19,
                          ),
                          onPressed: () {
                            AdminSession.loggedInRole = null;
                            AdminSession.loggedInShopId = null;
                            AdminSession.loggedInShopName = null;
                            AdminSession.loggedInEmail = null;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã đăng xuất khỏi cổng quản trị!')),
                            );
                            context.go(AdminRouter.login);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AdminPalette.border),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AdminPalette.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildConnectionPill(),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAdmin ? Icons.verified_user_rounded : Icons.store_rounded,
                                  size: 15,
                                  color: AdminPalette.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AdminSession.loggedInShopName ?? 'Super Admin',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AdminPalette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Page Content
                Expanded(
                  child: Container(
                    color: AdminPalette.bg,
                    padding: const EdgeInsets.all(28),
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
    required String subtitle,
    required String route,
    required bool isActive,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [AdminPalette.primary, AdminPalette.accent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFFE2E8F0),
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.78)
                            : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionPill() {
    final isOffline = AdminFallbackStore.isOfflineMode;
    final color = isOffline ? AdminPalette.warning : AdminPalette.success;
    final text = isOffline ? 'Chế độ Demo Dự Phòng (Offline)' : 'Supabase Cloud Live';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
