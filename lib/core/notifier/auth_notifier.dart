import 'package:flutter/foundation.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNotifier extends ChangeNotifier {
  Session? _session;
  AuthNotifier() {
    _session = SupabaseService.auth.currentSession;
    SupabaseService.auth.onAuthStateChange.listen((data){
      _session = data.session;
      notifyListeners();
    });
  }
  Session? get session => _session;
  bool get isAuthenticated => _session != null;
  String? get userId => _session?.user.id;
  VoidCallback? pendingAction;

  void setPendingAction(VoidCallback? action) {
    pendingAction = action;
  }

  void executePendingAction() {
    final action = pendingAction;
    pendingAction = null;
    action?.call();
  }
}
