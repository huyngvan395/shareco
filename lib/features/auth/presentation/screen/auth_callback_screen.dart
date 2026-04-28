import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/domain/usecases/exchange_code_usecase.dart';

import '../../../../core/services/supabase/index.dart';

class AuthCallbackScreen extends StatefulWidget {
  final Uri uri;

  const AuthCallbackScreen({super.key, required this.uri});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {

  late final ExchangeCodeUseCase _exchangeCode;

  @override
  void initState() {
    super.initState();
    _exchangeCode = sl<ExchangeCodeUseCase>();
    _handleAuth();
  }

  Future<void> _handleAuth() async {
    final code = widget.uri.queryParameters['code'];

    if (code == null) {
      context.go('/feed');
      return;
    }

    final result = await _exchangeCode(code);
    final authNotifier = sl<AuthNotifier>();

    result.fold(
          (failure) {
        authNotifier.setPendingAction(null);
        context.go('/feed');
      },
          (_) {
        authNotifier.executePendingAction();
        if (authNotifier.pendingAction == null) {

          context.go('/feed');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}