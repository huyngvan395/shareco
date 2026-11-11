// core/layout/navbar.dart

import 'package:flutter/material.dart';
import 'package:shareco/core/layout/main_scaffold.dart';
import 'package:shareco/core/services/notifications/push_notification_service.dart';
import 'package:shareco/di/injector.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';

class AppNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final TabTheme theme;

  const AppNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.theme,
  });

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, AppStrings.tabHome),
    (Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, AppStrings.tabStore),
    (null, null, AppStrings.tabCreate), // Centre — custom
    (Icons.mail_rounded, Icons.mail_outline, AppStrings.tabInbox),
    (Icons.person_rounded, Icons.person_outline, AppStrings.tabProfile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.navbarBackground,
        boxShadow: [
          BoxShadow(
            color: theme.navbarBackground == Colors.black
                ? Colors.white.withAlpha(20) // tab tối → shadow sáng nhẹ
                : Colors.black.withAlpha(15), // tab sáng → shadow tối nhẹ
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ]
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = currentIndex == i;
              final isCenter = i == 2;

              if (isCenter) return _CreateButton(onTap: () => onTap(i), theme: theme);

              if (i == 3 && sl.isRegistered<PushNotificationService>()) {
                final push = sl<PushNotificationService>();
                return Expanded(
                  child: ListenableBuilder(
                    listenable: push,
                    builder: (_, _) => _NavItem(
                      activeIcon: item.$1!,
                      inactiveIcon: item.$2!,
                      label: item.$3,
                      isActive: isActive,
                      onTap: () => onTap(i),
                      theme: theme,
                      badgeCount: push.unreadTotal,
                    ),
                  ),
                );
              }

              return Expanded(
                child: _NavItem(
                  activeIcon: item.$1!,
                  inactiveIcon: item.$2!,
                  label: item.$3,
                  isActive: isActive,
                  onTap: () => onTap(i),
                  theme: theme,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final TabTheme theme;
  final int badgeCount;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? theme.iconActive : theme.iconInactive,
                size: AppSizes.iconLg,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 1.5,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? theme.iconActive : theme.iconInactive,
              fontSize: AppSizes.fontXs,
              fontWeight:
              isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  final TabTheme theme;
  const _CreateButton({required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Layer phải (Brand Rose)
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Layer chính
                  Container(
                    width: 41,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.iconActive,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: theme.background,
                      size: 23,
                      weight: 900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        )
      ),
    );
  }
}