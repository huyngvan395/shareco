import 'package:flutter/material.dart';
import 'package:shareco/routes/admin_router.dart';
import 'package:shareco/features/ecommerce/admin/presentation/widgets/admin_ui_helpers.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShareCo Commerce Portal • Quản Trị Hệ Thống',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminPalette.primary,
          primary: AdminPalette.primary,
          secondary: AdminPalette.accent,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AdminPalette.bg,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminPalette.border),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AdminPalette.border,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminPalette.primary, width: 1.8),
          ),
        ),
      ),
      routerConfig: AdminRouter.router,
    );
  }
}
