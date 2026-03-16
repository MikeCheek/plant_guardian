import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:plant_guardian/widgets/garden_model.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones(); // Required for zonedSchedule

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        );

    await notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: notificationTapHandler,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );
  }

  Future<void> scheduleDailyNotification(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    await notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // This makes it repeat daily
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_channel_id',
      'Plant Alerts',
      channelDescription: 'Immediate reminders for plant care',
      importance: Importance.max,
      priority: Priority.high,
    );

    final details =
        notificationDetails ??
        NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        );

    await notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      // This checks and prompts the user to grant permission in system settings
      final bool? granted = await androidImplementation
          ?.requestExactAlarmsPermission();
      print("Exact Alarm Permission: $granted");
    }
  }

  /// Requests the POST_NOTIFICATIONS runtime permission on Android 13+ (API 33+).
  /// Must be called from the UI context before showing any notifications.
  Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImplementation?.requestNotificationsPermission();
    }
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackgroundHandler(
  NotificationResponse details,
) async {
  if (details.actionId == 'watered_action' && details.payload != null) {
    try {
      await Firebase.initializeApp();
      final data = jsonDecode(details.payload!) as Map<String, dynamic>;
      if (data['type'] == 'bulk_water') {
        final userId = data['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          await markAllThirstyAsWatered(userId);
        }
      }
    } catch (e) {
      print('Background notification handler error: $e');
    }
  }
}

// Handler for when the app is in the foreground
void notificationTapHandler(NotificationResponse details) {
  // You can navigate to a specific screen here if they tap the notification body
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp();

      // 2. IMPORTANT: Initialize Notifications inside the background isolate
      final notificationService = NotificationService();
      await notificationService.initNotification();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;

      // 3. MUST await this call
      await checkWateringNeedsAndNotify(user.uid);

      return true;
    } catch (e) {
      return false;
    }
  });
}
