import 'dart:io';

import 'package:ai_expense_tracker/peko.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/env.dart';
import 'core/di/injection.dart';
import 'core/di/notifications/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  print('OPENROUTER = ${Env.openRouterApiKey}');
  print('GROQ= ${Env.groqkey}');

  await EasyLocalization.ensureInitialized();

  // ✅ Firebase FIRST
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  // ✅ Notifications AFTER Firebase
  await NotificationService.initialize();

  // ✅ Request permission for Android 12+ exact alarms
  if (Platform.isAndroid) {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
    } else {
      debugPrint('Exact alarm permission denied');
    }
  } else {
    await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
  }

  setupDependencies();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(), // أو whatever your root widget is
    ),
  );
}