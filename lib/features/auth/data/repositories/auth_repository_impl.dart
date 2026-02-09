import 'package:shareco/features/auth/data/datasources/auth_remote_datasources.dart';
import 'package:shareco/features/auth/domain/entities/auth_session.dart';
import 'package:shareco/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository{
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<AuthSession> login(String email, String password, String type) async {
    final session = await remoteDataSource.login(email, password, type);
    if (session == null){
      throw Exception('Login failed');
    }
    return AuthSession(session.accessToken, session.refreshToken!);
  }

  @override
  Future<void> logout() {
    // TODO: implement logout
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register(String email, String password, String type) {
    // TODO: implement register
    throw UnimplementedError();
  }

}