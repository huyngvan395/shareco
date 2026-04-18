import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/domain/repositories/auth_repository.dart';

void requireAuth(BuildContext context, VoidCallback onAuthenticated) {
  final authRepo = sl<AuthRepository>();
  final session = authRepo.getCurrentSession();

  if (session == null){
    context.push("/login");
  }else {
    onAuthenticated();
  }
}
