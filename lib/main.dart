import 'dart:io';

import 'package:ai_expense_tracker/peko.dart';
import 'package:ai_expense_tracker/providers/currency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'config/env.dart';
import 'core/di/injection.dart';
import 'core/di/notifications/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  debugPrint('Environment loaded successfully');

  await EasyLocalization.ensureInitialized();

  await initializeRevenueCat();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService.initialize();

    }
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  await NotificationService.initialize();

  if (Platform.isAndroid) {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
    } else {
      debugPrint('Exact alarm permission denied');
      await NotificationService.scheduleDailyReminder(hour: 20, minute: 0);
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
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CurrencyProvider()),
            ],
            child: const MyApp(),
          );
        },
      ),
    ),
  );
}

Future<void> initializeRevenueCat() async {
  String apiKey;

  if (Platform.isIOS) {
    apiKey = 'test_LjLMrcZugNzKsjZAHLvtvfvekbl';
  } else if (Platform.isAndroid) {
    apiKey = 'test_LjLMrcZugNzKsjZAHLvtvfvekbl';
  } else {
    throw UnsupportedError('Platform not supported');
  }

  await Purchases.configure(PurchasesConfiguration(apiKey));
}