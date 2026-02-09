import 'package:shareco/core/constants/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService{
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async{
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }
}