import 'package:flutter/material.dart';

// core/navigation/app_route_observer.dart — theo dõi cả GoRoute lẫn Imperative Route/Dialog/Sheet trên Root Navigator
class AppRouteObserver extends NavigatorObserver {
  final _listeners = <VoidCallback>[];
  final Set<Route<dynamic>> _overlayRoutes = <Route<dynamic>>{};

  /// `true` khi có bất kỳ màn hình / bottom sheet nào (Livestream, CreateVideo, Camera, Wallet...)
  /// đang đè lên trên route gốc của MainScaffold.
  bool get hasOverlayRoute {
    _overlayRoutes.removeWhere((r) => !r.isActive);
    return _overlayRoutes.isNotEmpty;
  }

  void addRouteListener(VoidCallback cb) => _listeners.add(cb);
  void removeRouteListener(VoidCallback cb) => _listeners.remove(cb);

  void _notify() {
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _overlayRoutes.add(route);
    }
    _notify();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _overlayRoutes.remove(route);
    _notify();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _overlayRoutes.remove(route);
    _notify();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final wasOverlay = oldRoute != null && _overlayRoutes.remove(oldRoute);
    if (wasOverlay && newRoute != null) {
      _overlayRoutes.add(newRoute);
    }
    _notify();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

final routeObserver = AppRouteObserver();
