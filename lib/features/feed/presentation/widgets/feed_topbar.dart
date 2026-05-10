// features/feed/presentation/widgets/feed_topbar.dart

import 'package:flutter/material.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_event.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/feed_bloc.dart';

class FeedTopBar extends StatelessWidget {
  final FeedTab activeTab;
  final ValueChanged<FeedTab> onTabChanged;
  const FeedTopBar({super.key, required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: AppSizes.topBarHeight + top,
        padding: EdgeInsets.only(top: top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.65), Colors.transparent]),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(children: [
            _Tab(label: 'Đang theo dõi', isActive: activeTab == FeedTab.following,
                onTap: () => onTabChanged(FeedTab.following)),
            const SizedBox(width: AppSizes.xl),
            _Tab(label: 'Dành cho bạn', isActive: activeTab == FeedTab.forYou,
                onTap: () => onTabChanged(FeedTab.forYou)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.search_rounded, color: Colors.white, size: AppSizes.iconLg), onPressed: () {}),
          ]),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label; final bool isActive; final VoidCallback onTap;
  const _Tab({required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(
          color: isActive ? Colors.white : Colors.white54,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          fontSize: AppSizes.fontXl)),
      const SizedBox(height: 3),
      AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 2, width: isActive ? 24 : 0,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
    ]),
  );
}