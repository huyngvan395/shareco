import 'package:shareco/features/auth/domain/entities/auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSessionModel {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;

  AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  factory AuthSessionModel.fromSupabase(Session session) {
    final user = session.user;

    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken!,
      userId: user.id,
      email: user.email ?? '',
    );
  }

  AuthSession toEntity() {
    return AuthSession(
      userId: userId,
      email: email,
      accessToken: accessToken,
    );
  }
}
