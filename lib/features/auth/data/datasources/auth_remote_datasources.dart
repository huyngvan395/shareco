import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRemoteDataSource {
  Future<Session?> login(String email, String password, String type);
  Future<Session?> register(String email, String password, String type);
  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient client;

  AuthRemoteDataSourceImpl(this.client);

  @override
  Future<Session?> login(String email, String password, String type) async {
    AuthResponse? res;
    if (type == 'password'){
      res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    }
    return res?.session;
  }

  @override
  Future<Session?> logout() async {
    await client.auth.signOut();
    return null;
  }

  @override
  Future<Session?> register(String email, String password, String type) async {
    AuthResponse? res;
    if (type == 'password') {
      res = await client.auth.signUp(
        email: email,
        password: password,
      );
    }
    return res?.session;
  }

}
