import 'package:shareco/features/auth/domain/entities/auth_session.dart';
import 'package:shareco/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<AuthSession> call(String email, String password, String type) {
    return repository.login(email, password, type);
  }
}
