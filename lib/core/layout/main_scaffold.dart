
// core/layout/main_scaffold.dart
//
// MainScaffold dùng StatefulShellRoute của GoRouter.
// Mỗi tab giữ navigator riêng → giữ nguyên state khi chuyển tab.
//
// StatefulShellRoute.indexedStack phân phối:
//   index 0 → /feed      (FeedScreen)
//   index 1 → /discover
//   index 2 → /create
//   index 3 → /chat
//   index 4 → /profile

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/routes/app_router.dart';
import '../constants/app_colors.dart';
import 'navbar.dart';
import '../helpers/require_auth.dart';

class MainScaffold extends StatelessWidget {
  /// Shell state do GoRouter cung cấp — quản lý tab navigator
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const _navToBranch = {
    0: 0, // feed
    1: 1, // ecommerce
    3: 2, // chat
    4: 3, // profile
  };

  static const _branchToNav = {
    0: 0, // feed
    1: 1, // ecommerce
    2: 3, // chat  (navbar index 3)
    3: 4, // profile (navbar index 4)
  };

  void _onTabTap(BuildContext context, int navIndex) {
    if (navIndex == 2) {
      context.requireAuth(() => context.push(Routes.create));
      return;
    }

    final branchIndex = _navToBranch[navIndex]!;

    if ((navIndex == 3 || navIndex == 4) && !context.isAuthenticated) {
      context.requireAuth(() => navigationShell.goBranch(branchIndex));
      return;
    }

    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _tabThemes[navigationShell.currentIndex]!;
    final navIndex = _branchToNav[navigationShell.currentIndex] ?? 0;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: theme.background,
      // navigationShell.currentIndex theo dõi tab hiện tại
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: AppNavbar(
        currentIndex: navIndex,
        onTap: (index) => _onTabTap(context, index),
        theme: theme,
      ),
    );
  }
}

class TabTheme {
  final Color background;
  final Color navbarBackground;
  final Color iconActive;
  final Color iconInactive;

  const TabTheme({
    required this.background,
    required this.navbarBackground,
    required this.iconActive,
    required this.iconInactive,
  });
}

const _tabThemes = {
  0: TabTheme(
    background: Colors.black,
    navbarBackground: Colors.black,
    iconActive: Colors.white,
    iconInactive: AppColors.iconMuted,
  ),
  1: TabTheme(
    background: Colors.white,
    navbarBackground: Colors.white,
    iconActive: Colors.black,
    iconInactive: Colors.grey,
  ),
  2: TabTheme(
    background: Colors.white,
    navbarBackground: Colors.white,
    iconActive: Colors.black,
    iconInactive: Colors.grey,
  ),
  3: TabTheme(
    background: Colors.white,
    navbarBackground: Colors.white,
    iconActive: Colors.black,
    iconInactive: Colors.grey,
  ),
  // 4: TabTheme(
  //   background: Colors.white,
  //   navbarBackground: Colors.white,
  //   iconActive: Colors.black,
  //   iconInactive: Colors.grey,
  // ),
};
