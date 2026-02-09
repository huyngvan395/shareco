import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty){
      throw Exception("Supabase Url not found!");
    }
    return url;
  }
  static String get supabaseAnonKey {
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (anonKey == null || anonKey.isEmpty){
      throw Exception("Supabase anon key not found!");
    }
    return anonKey;
  }
}