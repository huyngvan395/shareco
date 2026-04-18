import 'package:shareco/features/auth/domain/entities/auth_session.dart';
import 'package:shareco/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<AuthSession> call(String email, String password, String type) {
    return repository.register(email, password, type);
  }

}