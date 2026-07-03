// lib/core/notifications/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
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

  static final _notificationStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationStreamController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _notifications = FlutterLocalNotificationsPlugin();
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
  }

  static Future<void> _saveToFirestore({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<int> getUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<QuerySnapshot> getNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  static Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  static Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

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

  static Future<void> showNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
    bool saveToFirestore = true,
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

    if (saveToFirestore) {
      await _saveToFirestore(
        title: title,
        body: body,
        type: type ?? 'general',
        data: data,
      );
    }
  }

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

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      99999,
      '📝 Daily Check-in',
      'Don\'t forget to track your expenses and income today!',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          '${_channel.id}_daily',
          'Daily Reminders',
          channelDescription: 'Daily reminder to log expenses',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'reminder', 'screen': '/home'}),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _notifications.cancel(99999);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

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

  static Future<void> sendBudgetAlert({
    required String budgetName,
    required double remaining,
    required double total,
  }) async {
    final percent = ((total - remaining) / total * 100).toStringAsFixed(0);

    await showNotification(
      title: '⚠️ Budget Alert',
      body: '"$budgetName" is at $percent%! Only \$${remaining.toStringAsFixed(0)} remaining.',
      type: 'budget',
      data: {
        'screen': '/budget',
        'budgetName': budgetName,
      },
    );
  }

  static Future<void> sendGoalAchieved({
    required String goalName,
    required double targetAmount,
    required String currencySymbol,
  }) async {
    final formattedAmount = '$currencySymbol${targetAmount.toStringAsFixed(0)}';

    await showNotification(
      title: '🎉 Goal Achieved!',
      body: 'You\'ve reached $formattedAmount for "$goalName"! Amazing work! 🎯',
      type: 'goal',
      data: {
        'screen': '/budget',
        'tab': 'goals',
        'goalName': goalName,
      },
      saveToFirestore: true,
    );
  }

  /// ✅ Weekly Summary
  static Future<void> sendWeeklySummary({
    required double totalSpent,
    required double totalIncome,
  }) async {
    final net = totalIncome - totalSpent;
    final emoji = net >= 0 ? '📈' : '📉';

    await showNotification(
      title: '$emoji Weekly Summary',
      body:
      'Spent: \$${totalSpent.toStringAsFixed(0)} | Income: \$${totalIncome.toStringAsFixed(0)} | Net: \$${net.toStringAsFixed(0)}',
      type: 'summary',
      data: {'screen': '/stats'},
    );
  }
}