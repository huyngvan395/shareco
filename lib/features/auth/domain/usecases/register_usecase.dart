// features/auth/domain/usecases/register_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;
  const RegisterUseCase(this.repository);

  Future<Either<Failure, AuthSession>> call({
    required String email,
    required String password,
    required String username,
  }) =>
      repository.register(
        email: email,
        password: password,
        username: username,
      );
}