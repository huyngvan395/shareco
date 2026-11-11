import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shareco/app.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/core/services/notifications/push_notification_service.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:shareco/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();
  await setupInjector();
  await sl<PushNotificationService>().init();
  final authNotifier = sl<AuthNotifier>();
  runApp(App(authNotifier: authNotifier));
}
