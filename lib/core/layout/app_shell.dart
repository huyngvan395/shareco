import 'package:flutter/material.dart';
import '../../di/injector.dart';
import '../services/notifications/push_notification_service.dart';
import '../services/supabase/presence_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver {
  PresenceService get _presence => sl<PresenceService>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _presence.setOnline();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    switch (state) {
      case AppLifecycleState.resumed:
        _presence.setOnline();
        if (sl.isRegistered<PushNotificationService>()) {
          sl<PushNotificationService>().refreshUnreadSummary();
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _presence.setOffline();
        break;
    }
  }

  @override
  void dispose() {
    _presence.setOffline();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}