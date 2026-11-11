// features/auth/data/datasources/auth_remote_datasources.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../../core/errors/exception.dart';
import '../../../../core/notifier/auth_notifier.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<AuthSessionModel> register({
    required String email,
    required String password,
    required String username,
  });

  Future<void> exchangeCode(String code);

  Future<void> logout();

  Future<AuthSessionModel?> getCurrentSession();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        throw const AuthException('Đăng nhập thất bại: không nhận được phiên đăng nhập.');
      }
      if (sl.isRegistered<AuthNotifier>()) {
        sl<AuthNotifier>().syncSession(response.session);
      }
      return AuthSessionModel.fromSupabase(response.session!);
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      debugPrint('AuthApiException: $e');
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('ServerException: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthSessionModel> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      if (response.user == null) {
        throw const AuthException('Đăng ký tài khoản thất bại.');
      }
      if (response.session == null) {
        throw const AuthException(
          'Đăng ký thành công! Vui lòng kiểm tra email để xác nhận tài khoản.',
        );
      }
      if (sl.isRegistered<AuthNotifier>()) {
        sl<AuthNotifier>().syncSession(response.session);
      }
      return AuthSessionModel.fromSupabase(response.session!);
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (sl.isRegistered<AuthNotifier>()) {
        await sl<AuthNotifier>().signOut();
      } else {
        await SupabaseService.auth.signOut();
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthSessionModel?> getCurrentSession() async {
    final session = SupabaseService.auth.currentSession;
    if (session == null) return null;
    return AuthSessionModel.fromSupabase(session);
  }

  @override
  Future<void> exchangeCode(String code) async {
    try {
      final response = await SupabaseService.auth.exchangeCodeForSession(code);
      if (sl.isRegistered<AuthNotifier>()) {
        sl<AuthNotifier>().syncSession(response.session);
      }
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
