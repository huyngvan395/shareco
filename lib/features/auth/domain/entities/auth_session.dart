// features/auth/domain/entities/auth_session.dart

import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  final String userId;
  final String email;
  final String? accessToken;

  const AuthSession({
    required this.userId,
    required this.email,
    this.accessToken,
  });

  @override
  List<Object?> get props => [userId, email, accessToken];
}