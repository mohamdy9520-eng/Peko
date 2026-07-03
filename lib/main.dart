import 'dart:io';

import 'package:ai_expense_tracker/peko.dart';
import 'package:ai_expense_tracker/providers/currency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'core/di/injection.dart';
import 'core/di/notifications/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Env & Localization FIRST
  await Env.load();
  debugPrint('Environment loaded successfully');

  await EasyLocalization.ensureInitialized();

  // ✅ Firebase BEFORE notifications (عشان Firestore notifications تحتاج Firebase)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  // ✅ Initialize Notifications ONCE
  await NotificationService.initialize();

  // ✅ Request permission for Android 12+ exact alarms
  if (Platform.isAndroid) {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
    } else {
      debugPrint('Exact alarm permission denied');
      // ✅ لو ماخدش permission، نبعت notification عادية (inexact)
      await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
    }
  } else {
    // iOS — مش محتاج exact alarm permission
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
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}