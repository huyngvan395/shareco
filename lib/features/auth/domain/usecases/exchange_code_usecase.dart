import 'package:dartz/dartz.dart';
import 'package:shareco/core/errors/failure.dart';

import '../repositories/auth_repository.dart';

class ExchangeCodeUseCase {
  final AuthRepository repository;

  ExchangeCodeUseCase(this.repository);

  Future<Either<Failure, void>> call(String code) {
    return repository.exchangeCode(code);
  }
}