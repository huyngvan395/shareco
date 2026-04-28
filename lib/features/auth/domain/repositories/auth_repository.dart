// features/auth/domain/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthSession>> register({
    required String email,
    required String password,
    required String username,
  });

  Future<Either<Failure, void>> exchangeCode(String code);


  Future<Either<Failure, void>> logout();

  Future<Either<Failure, AuthSession?>> getCurrentSession();
}