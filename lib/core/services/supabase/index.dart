// core/services/supabase/index.dart
// Wrapper singleton cho Supabase — cung cấp các helper method tiện dụng

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/env.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static GoTrueClient get auth => client.auth;
  static String? get currentUserId => client.auth.currentUser?.id;
  static bool get isAuthenticated => client.auth.currentUser != null;

  // ── Database ──────────────────────────────────────────────────────────────
  static SupabaseQueryBuilder from(String table) => client.from(table);

  // ── RPC ───────────────────────────────────────────────────────────────────
  static Future<dynamic> rpc(
      String fn, {
        Map<String, dynamic>? params,
      }) =>
      client.rpc(fn, params: params);

  // ── Storage ───────────────────────────────────────────────────────────────
  static SupabaseStorageClient get storage => client.storage;

  static StorageFileApi bucket(String name) => client.storage.from(name);

  /// Lấy public URL từ storage path
  static String publicUrl(String bucket, String path) =>
      client.storage.from(bucket).getPublicUrl(path);

  // ── Realtime ──────────────────────────────────────────────────────────────
  static RealtimeClient get realtime => client.realtime;

  // ── Pagination helper ─────────────────────────────────────────────────────
  /// Convert page + limit thành range cho Supabase
  static (int, int) pageRange(int page, int limit) {
    final from = page * limit;
    final to = from + limit - 1;
    return (from, to);
  }
}