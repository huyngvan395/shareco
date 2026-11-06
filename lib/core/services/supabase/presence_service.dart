// core/services/presence_service.dart

import 'dart:async';

import 'package:shareco/core/services/supabase/index.dart';

class PresenceService {
  final _client = SupabaseService.client;
  Timer? _heartbeatTimer;

  Future<void> setOnline() async {
    _heartbeatTimer?.cancel();
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _client.from('profiles').update({
        'is_online': true,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {}

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await _client.from('profiles').update({
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {}
    });
  }

  Future<void> setOffline() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _client.from('profiles').update({
        'is_online': false,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> watchUserPresence(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isNotEmpty ? rows.first : {});
  }
}