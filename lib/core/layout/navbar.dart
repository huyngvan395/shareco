import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Navbar extends StatelessWidget {
  const Navbar({super.key});

  int _getIndex(String location) {
    if (location.startsWith('/video')) return 1;
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/chat')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _getIndex(location);
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (index) {},
      items: const [],
    );
  }
}
