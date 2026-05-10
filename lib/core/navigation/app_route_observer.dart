import 'package:flutter/material.dart';

// core/navigation/app_route_observer.dart — mở rộng
class AppRouteObserver extends NavigatorObserver {
  final _listeners = <VoidCallback>[];

  void addRouteListener(VoidCallback cb) => _listeners.add(cb);
  void removeRouteListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() { for (final cb in _listeners) {
    cb();
  } }

  @override
  void didPush(Route route, Route? previousRoute) {
    _notify();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _notify();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _notify();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

final routeObserver = AppRouteObserver();
