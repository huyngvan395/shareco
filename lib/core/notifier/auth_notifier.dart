import 'package:flutter/foundation.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  AuthNotifier() {
    _isAuthenticated = SupabaseService.client.auth.currentSession != null;
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      switch (event) {
        case AuthChangeEvent.signedIn:
          _isAuthenticated = true;
          notifyListeners();
          break;
        case AuthChangeEvent.signedOut:
          _isAuthenticated = false;
          notifyListeners();
          break;
        default:
          if (kDebugMode) {
            debugPrint('No event!');
          }
      }
    });
  }
}
