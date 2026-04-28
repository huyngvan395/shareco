import 'package:shareco/core/constants/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService{
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async{
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }

  static SupabaseQueryBuilder from(String table) => client.from(table);

  static GoTrueClient get auth => client.auth;

  static RealtimeClient get realtime => client.realtime;

  static SupabaseStorageClient get storage => client.storage;

}