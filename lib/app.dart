import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/constants/app_colors.dart';
import 'package:shareco/core/layout/app_shell.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/core/services/notifications/in_app_push_banner.dart';
import 'package:shareco/core/services/notifications/push_notification_service.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/routes/app_router.dart';

class App extends StatefulWidget {
  final AuthNotifier authNotifier;

  const App({super.key, required this.authNotifier});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router(widget.authNotifier);
    sl<PushNotificationService>().attachRouter(_router);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  ThemeData _buildAppTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      highlightColor: AppColors.primary.withValues(alpha: 0.04),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        focusColor: AppColors.primary,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        prefixIconColor: AppColors.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pushService = sl<PushNotificationService>();
    return AppShell(
      child: MaterialApp.router(
        title: 'Shareco',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(),
        routerConfig: _router,
        builder: (navContext, child) {
          pushService.attachContext(navContext);
          return InAppPushBannerOverlay(
            service: pushService,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
