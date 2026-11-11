import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:shareco/core/services/supabase/presence_service.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/ecommerce/cart/data/datasources/cart_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNotifier extends ChangeNotifier {
  Session? _session;
  StreamSubscription<AuthState>? _authSub;
  bool _isSigningOut = false;

  AuthNotifier() {
    _session = SupabaseService.auth.currentSession;
    _authSub = SupabaseService.auth.onAuthStateChange.listen((data) {
      final prevUserId = _session?.user.id;
      final nextSession = data.session;
      final nextUserId = nextSession?.user.id;

      _session = nextSession;

      if (data.event == AuthChangeEvent.signedOut) {
        pendingAction = null;
        if (sl.isRegistered<CartRemoteDataSource>()) {
          sl<CartRemoteDataSource>().clearCache();
        }
      } else if (nextUserId != null && prevUserId != nextUserId) {
        if (sl.isRegistered<PresenceService>()) {
          unawaited(sl<PresenceService>().setOnline());
        }
      }

      if (prevUserId != nextUserId ||
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.userUpdated) {
        notifyListeners();
      }
    });
  }

  Session? get session => _session;
  bool get isAuthenticated => _session != null;
  String? get userId => _session?.user.id;
  bool get isSigningOut => _isSigningOut;
  VoidCallback? pendingAction;

  /// Đồng bộ ngay lập tức session sau khi đăng nhập / đăng ký thành công
  /// trước khi GoRouter redirect hoặc pendingAction chạy.
  void syncSession([Session? updatedSession]) {
    final prevUserId = _session?.user.id;
    _session = updatedSession ?? SupabaseService.auth.currentSession;
    final nextUserId = _session?.user.id;

    if (nextUserId != null && prevUserId != nextUserId) {
      if (sl.isRegistered<CartRemoteDataSource>()) {
        sl<CartRemoteDataSource>().clearCache();
      }
      if (sl.isRegistered<PresenceService>()) {
        unawaited(sl<PresenceService>().setOnline());
      }
    }

    if (prevUserId != nextUserId) {
      notifyListeners();
    }
  }

  /// Đăng xuất tài khoản an toàn:
  /// 1. Đánh dấu offline trên bảng profiles khi token còn hiệu lực
  /// 2. Xóa cache giỏ hàng & pendingAction
  /// 3. Gọi signOut của Supabase (có fallback local nếu mất mạng / token hết hạn)
  /// 4. Cập nhật trạng thái ngay lập tức để UI & Router chuyển hướng sạch sẽ
  Future<void> signOut() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    try {
      pendingAction = null;
      if (sl.isRegistered<PresenceService>()) {
        await sl<PresenceService>().setOffline();
      }
      if (sl.isRegistered<CartRemoteDataSource>()) {
        sl<CartRemoteDataSource>().clearCache();
      }

      try {
        await SupabaseService.auth.signOut();
      } catch (e) {
        debugPrint('Supabase signOut remote warning: $e');
        try {
          await SupabaseService.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
      }

      final hadSession = _session != null;
      _session = null;
      if (hadSession) {
        notifyListeners();
      }
    } finally {
      _isSigningOut = false;
    }
  }

  void setPendingAction(VoidCallback? action) {
    pendingAction = action;
  }

  void executePendingAction() {
    final action = pendingAction;
    pendingAction = null;
    action?.call();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
