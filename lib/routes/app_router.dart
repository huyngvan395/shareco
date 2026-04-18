import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/layout/main_scaffold.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:shareco/features/auth/presentation/screen/login_screen.dart';

import '../features/auth/presentation/bloc/register/register_bloc.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const home = "/login";
  static const myProfile = "/my-profile";
  static const profile = "/profile";
  static const video = "/video";
  static const post = "/post";
  static const chat = "/chat";
}

class AppRouter {
  static GoRouter router(AuthNotifier authNotifier) => GoRouter(
    refreshListenable: authNotifier,
    initialLocation: Routes.login,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.isAuthenticated;
      final needAuthRoutes = [Routes.chat, Routes.post, Routes.myProfile];
      final checkNeedAuthRoutes = needAuthRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );

      if (!isLoggedIn && checkNeedAuthRoutes) {
        return Routes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<LoginBloc>(),
            child: LoginScreen(state: state),
          );
        },
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<RegisterBloc>(),
            child: LoginScreen(state: state),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child){
          return MultiBlocProvider(
              providers: [

              ],
              child: MainScaffold(child: child)
          );
        },
        routes: [

        ]
      )
    ],
  );
}
