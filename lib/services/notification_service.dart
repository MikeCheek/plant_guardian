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
          iOS: DarwinInitializationSettings(),
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
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse details) async {
  if (details.actionId == 'watered_action') {
    // Logic to update Firestore: You'll need to pass the plant/garden ID in the payload
    final data = jsonDecode(details.payload!);
    waterPlant(data['gardenId'], data['plantId'], data['userId']);
    print("Plant ${data['plantId']} marked as watered!");
  }
}

// Handler for when the app is in the foreground
void notificationTapHandler(NotificationResponse details) {
  // You can navigate to a specific screen here if they tap the notification body
}

@pragma('vm:entry-point') // Mandatory for Release mode
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize Firebase for the background process
      await Firebase.initializeApp();

      // 2. Get the current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      // 3. Run your check logic from garden_model
      await checkWateringNeedsAndNotify(user.uid);

      return Future.value(true);
    } catch (e) {
      print("Background Task Failed: $e");
      return Future.value(false);
    }
  });
}
