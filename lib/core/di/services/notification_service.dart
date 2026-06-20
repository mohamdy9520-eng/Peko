import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestPermissions();
    await _initializeLocalNotifications();
    await _getToken();
    _fcm.onTokenRefresh.listen(_handleTokenRefresh);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    await _checkInitialMessage();
  }

  static Future<void> _requestPermissions() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'goal_channel',
        'Goal Notifications',
        description: 'Notifications for savings goals and achievements',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<String?> _getToken() async {
    try {
      if (Platform.isIOS) {
        await _fcm.getAPNSToken();
      }
      _fcmToken = await _fcm.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  static void _handleTokenRefresh(String newToken) {
    _fcmToken = newToken;
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      showNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('👆 Local notification tapped: $data');
      } catch (e) {
        debugPrint('Error parsing payload: $e');
      }
    }
  }

  static Future<void> _checkInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(message);
      });
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'goal_channel',
      'Goal Notifications',
      channelDescription: 'Notifications for savings goals',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> scheduleMonthlyReminder({
    required String goalName,
    required double amount,
    required int dayOfMonth,
  }) async {
    await _localNotifications.zonedSchedule(
      goalName.hashCode,
      '💰 Monthly Savings Reminder',
      'Save \$$amount for "$goalName" today!',
      _nextInstanceOfDay(dayOfMonth),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_reminder',
          'Savings Reminders',
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static tz.TZDateTime _nextInstanceOfDay(int day) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, day, 9, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 30));
    }
    return scheduled;
  }
}