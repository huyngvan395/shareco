import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSessionModel {
  final String accessToken;
  final String refreshToken;

  AuthSessionModel({required this.accessToken, required this.refreshToken});

  factory AuthSessionModel.fromSupabase(Session session){
    return AuthSessionModel(accessToken: session.accessToken, refreshToken: session.refreshToken!);
  }

}
