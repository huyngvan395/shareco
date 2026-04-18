import 'package:shareco/features/auth/domain/entities/auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<AuthSession> login(String email, String password, String type);

  Future<AuthSession> register(String email, String password, String type);

  Future<void> logout();

  Session? getCurrentSession();
}
