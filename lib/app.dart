import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
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
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Shareco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      routerConfig: AppRouter.router(widget.authNotifier),
    );
  }
}
