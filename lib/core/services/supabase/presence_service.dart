// core/services/presence_service.dart

import 'dart:async';

import 'package:shareco/core/services/supabase/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  final _client = SupabaseService.client;
  Timer? _heartbeatTimer;

  Future<void> setOnline() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client.from('profiles').update({
      'is_online': true,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _client.from('profiles').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    });
  }

  Future<void> setOffline() async {
    _heartbeatTimer?.cancel();
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client.from('profiles').update({
      'is_online': false,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Stream<Map<String, dynamic>> watchUserPresence(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isNotEmpty ? rows.first : {});
  }
}