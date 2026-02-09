import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shareco/app.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:shareco/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseService.init();
  await initInjector();
  final authNotifier = AuthNotifier();
  runApp(App(authNotifier: authNotifier));
}