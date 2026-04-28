// features/auth/domain/usecases/login_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  const LoginUseCase(this.repository);

  Future<Either<Failure, AuthSession>> call({
    required String email,
    required String password,
  }) =>
      repository.login(email: email, password: password);
}