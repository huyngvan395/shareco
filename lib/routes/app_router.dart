import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/layout/main_scaffold.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:shareco/features/auth/presentation/screen/auth_callback_screen.dart';
import 'package:shareco/features/auth/presentation/screen/login_screen.dart';
import 'package:shareco/features/auth/presentation/screen/register_screen.dart';
import 'package:shareco/features/chat/presentation/screen/chat_screen.dart';
import 'package:shareco/features/ecommerce/product/presentation/screen/product_list_screen.dart';
import 'package:shareco/features/feed/presentation/screen/feed_screen.dart';
import 'package:shareco/features/profile/presentation/screen/profile_screen.dart';
import 'package:shareco/features/video/presentation/screen/create_video_screen.dart';

import '../features/auth/presentation/bloc/register/register_bloc.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const feed = "/feed";
  static const myProfile = "/my-profile";
  static const profile = "/profile";
  static const video = "/video";
  static const post = "/post";
  static const chat = "/chat";
  static const create = "/create";
  static const discover = "/discover";
  static const ecommerce = "/ecommerce";

}

class AppRouter {
  static GoRouter router(AuthNotifier authNotifier) => GoRouter(
    refreshListenable: authNotifier,
    initialLocation: Routes.feed,
    routes: [
      // GoRoute(
      //   path: Routes.login,
      //   builder: (context, state) {
      //     return BlocProvider(
      //       create: (_) => sl<LoginBloc>(),
      //       child: LoginScreen(),
      //     );
      //   },
      // ),
      // GoRoute(
      //   path: Routes.register,
      //   builder: (context, state) {
      //     return BlocProvider(
      //       create: (_) => sl<RegisterBloc>(),
      //       child: RegisterScreen(),
      //     );
      //   },
      // ),
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      GoRoute(
        path: Routes.create,
        builder: (_, _) => const CreateVideoScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.feed,
              builder: (_,_) => const FeedScreen()
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.ecommerce,
              builder: (_,_) => const ProductListScreen()
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.chat,
              builder: (_,_) => const ChatScreen()
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.myProfile,
              builder: (_,_) => const ProfileScreen()
            )
          ])
        ]
      )
    ],
  );
}
