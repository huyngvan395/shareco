import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shareco/admin_app.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:shareco/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URL strategy without '#' for premium web feeling
  await dotenv.load(fileName: '.env');
  await SupabaseService.init();
  await setupInjector();
  runApp(const AdminApp());
}
