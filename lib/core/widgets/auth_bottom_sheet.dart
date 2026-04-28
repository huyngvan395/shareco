// core/widgets/auth_bottom_sheet.dart
//
// AuthBottomSheet là điểm duy nhất xử lý auth flow.
// GoRouter không biết gì về việc này.
//
// Cấu trúc:
//   DraggableScrollableSheet
//     └── MultiBlocProvider [LoginBloc, RegisterBloc]
//           └── Navigator nội bộ (độc lập với GoRouter)
//                 ├── '/'          → GateScreen
//                 ├── '/login'     → LoginScreen
//                 └── '/register'  → RegisterScreen
//
// Sau khi đăng nhập / đăng kí thành công:
//   1. Đóng sheet (rootNavigator.pop)
//   2. Gọi pendingAction nếu có (từ context.requireAuth)
//   3. AuthNotifier phát event → app tự react (rebuild tab, v.v.)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import '../../di/injector.dart';
import '../../features/auth/presentation/bloc/login/login_bloc.dart';
import '../../features/auth/presentation/bloc/register/register_bloc.dart';
import '../../features/auth/presentation/screen/gate_screen.dart';
import '../../features/auth/presentation/screen/login_screen.dart';
import '../../features/auth/presentation/screen/register_screen.dart';
import '../constants/app_colors.dart';

class AuthBottomSheet {
  static final GlobalKey<NavigatorState> _sheetNavKey = GlobalKey();
  static void show(
      BuildContext context, {
        VoidCallback? pendingAction,
      }) async {
    if (pendingAction != null) {
      sl<AuthNotifier>().setPendingAction(pendingAction);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => _AuthSheetScaffold(pendingAction: pendingAction, sheetNavKey: _sheetNavKey),
    );
  }
}

// ─── Shell ─────────────────────────────────────────────────────────────────────

class _AuthSheetScaffold extends StatelessWidget {
  final VoidCallback? pendingAction;
  final GlobalKey<NavigatorState> sheetNavKey;

  const _AuthSheetScaffold({this.pendingAction, required this.sheetNavKey});

  @override
  Widget build(BuildContext context) {
    final scaffoldContext = context;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LoginBloc(loginUseCase: sl())),
        BlocProvider(create: (_) => RegisterBloc(registerUseCase: sl())),
      ],
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, sc) => _SheetContainer(
          scrollController: sc,
          child: _SheetNavigator(pendingAction: pendingAction, sheetNavKey: sheetNavKey, outerContext:scaffoldContext),
        ),
      ),
    );
  }
}

// ─── Navigator nội bộ ─────────────────────────────────────────────────────────

class _SheetNavigator extends StatelessWidget {
  final VoidCallback? pendingAction;
  final GlobalKey<NavigatorState> sheetNavKey ;
  final BuildContext outerContext;

  const _SheetNavigator({this.pendingAction, required this.sheetNavKey, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: sheetNavKey,
      onGenerateRoute: (settings) {
        late Widget page;
        void onSuccess() {
          Navigator.of(outerContext, rootNavigator: true).pop();
          if (pendingAction != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => pendingAction!());
          }
        }

        switch (settings.name) {
          case '/login':
            page = LoginScreen(
              onBack: () => Navigator.of(outerContext).pop(),
              onNavigateToRegister: () =>
                  sheetNavKey.currentState!.pushNamed('/register'),
              onSuccess: () => onSuccess(),
            );
            break;
          case '/register':
            page = RegisterScreen(
              onBack: () => Navigator.of(outerContext).pop(),
              onNavigateToLogin: () => sheetNavKey.currentState!.pushNamed('/login'),
              onSuccess: () => onSuccess(),
            );
            break;
          default: // '/'
            page = GateScreen(
              onBack:() => Navigator.of(outerContext).pop(),
              onNavigateToLogin: () =>
                  sheetNavKey.currentState!.pushNamed('/login'),
              onNavigateToRegister: () =>
                  sheetNavKey.currentState!.pushNamed('/register'),
              onDismiss: () =>
                  Navigator.of(outerContext, rootNavigator: true).pop(),
            );
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, anim, _, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
      },
    );
  }
}

// ─── Container ─────────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final ScrollController scrollController;
  final Widget child;
  const _SheetContainer(
      {required this.scrollController, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(child: child),
      ]),
    );
  }
}