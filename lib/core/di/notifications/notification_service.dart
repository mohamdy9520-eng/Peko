// lib/core/notifications/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  // ✅ late بدل final
  static late FlutterLocalNotificationsPlugin _notifications;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'expense_tracker_channel',
    'Expense Tracker Notifications',
    description: 'Notifications for budgets, goals, and transactions',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool _initialized = false;

  /// Stream للـ Navigation
  static final _notificationStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationStreamController.stream;

  /// تهيئة النظام — بتتنادى مرة واحدة في main()
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // ✅ Initialize here
    _notifications = FlutterLocalNotificationsPlugin();

    tz_data.initializeTimeZones();

    // Android Settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    // Create Android Channel
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    // Request permission for iOS
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle FCM when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle FCM when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
  }

  /// لما المستخدم يضغط على Notification
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _notificationStreamController.add(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  static void _onBackgroundTap(NotificationResponse response) {
    _onNotificationTap(response);
  }

  /// إرسال Notification فوري
  static Future<void> showNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final payload = jsonEncode({
      'type': type ?? 'general',
      ...?data,
    });

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4A9B8C),
          enableLights: true,
          ledColor: const Color(0xFF4A9B8C),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// إرسال Notification مجدول
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final payload = jsonEncode({
      'type': type ?? 'general',
      ...?data,
    });

    await _notifications.zonedSchedule(
      DateTime.now().millisecond,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// إلغاء كل الـ Notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Handle FCM Foreground
  static void _handleForegroundMessage(RemoteMessage message) {
    showNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      type: message.data['type'],
      data: message.data,
    );
  }

  static void _handleInitialMessage(RemoteMessage? message) {
    if (message == null) return;
  }

  /// Budget Alert
  static Future<void> sendBudgetAlert({
    required String budgetName,
    required double remaining,
    required double total,
  }) async {
    final percent = (remaining / total * 100).toStringAsFixed(0);

    await showNotification(
      title: '⚠️ Budget Alert',
      body: '"$budgetName" is $percent% used. \$${remaining.toStringAsFixed(0)} remaining.',
      type: 'budget',
      data: {
        'screen': '/budget',
        'budgetName': budgetName,
      },
    );
  }

  /// Goal Achieved
  static Future<void> sendGoalAchieved({
    required String goalName,
    required double targetAmount,
  }) async {
    await showNotification(
      title: '🎉 Goal Achieved!',
      body: 'You\'ve reached \$${targetAmount.toStringAsFixed(0)} for "$goalName"!',
      type: 'goal',
      data: {
        'screen': '/budget',
        'tab': 'goals',
      },
    );
  }

  /// Weekly Summary
  static Future<void> sendWeeklySummary({
    required double totalSpent,
    required double totalIncome,
  }) async {
    final net = totalIncome - totalSpent;
    final emoji = net >= 0 ? '📈' : '📉';

    await showNotification(
      title: '$emoji Weekly Summary',
      body: 'Spent: \$${totalSpent.toStringAsFixed(0)} | Income: \$${totalIncome.toStringAsFixed(0)} | Net: \$${net.toStringAsFixed(0)}',
      type: 'summary',
      data: {
        'screen': '/stats',
      },
    );
  }

  /// Daily Reminder
  static Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await scheduleNotification(
      title: '📝 Daily Check-in',
      body: 'Don\'t forget to track your expenses today!',
      scheduledDate: scheduled,
      type: 'reminder',
    );
  }
}