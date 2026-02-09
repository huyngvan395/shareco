import 'package:flutter/material.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/routes/app_router.dart';

class App extends StatelessWidget {
  final AuthNotifier authNotifier;
  const App({super.key, required this.authNotifier});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
        title: 'Shareco',
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
    routerConfig: AppRouter.router(authNotifier),
    );
  }
}
