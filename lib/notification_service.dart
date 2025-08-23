// notification_service.dart
// This service manages all local notification logic for the app.

// --- UPDATE NOTES ---
// 1. Added `audioAttributesUsage: AudioAttributesUsage.alarm` to the
//    alarm channel. This is a powerful setting that tells the Android OS
//    to treat the notification sound as a high-priority alarm, which can
//    override silent modes and battery optimization settings.
// 2. Kept the debugging logic to recreate notification channels on startup.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- NOTIFICATION DETAILS CONSTANTS ---
  static const NotificationDetails _standardNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      'standard_channel_id',
      'Standard Reminders',
      channelDescription: 'Channel for standard, quiet reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  static const NotificationDetails _alarmNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      'alarm_channel_id',
      'Alarm Reminders',
      channelDescription: 'Channel for loud, persistent alarm reminders',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      // FIXED: Classify the sound as a high-priority ALARM for the OS.
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      sound: 'alarm.aiff',
    ),
  );

  Future<void> init() async {
    print("🔔 [NotificationService] Initializing...");

    if (kDebugMode) {
      final androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        print("  -> (Debug) Deleting old notification channels...");
        await androidImplementation
            .deleteNotificationChannel('standard_channel_id');
        await androidImplementation
            .deleteNotificationChannel('alarm_channel_id');
        print("  -> (Debug) Channels deleted.");
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    tz.initializeTimeZones();
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print("✅ [NotificationService] Initialization complete.");
  }

  Future<void> requestPermissions() async {
    print("🔔 [NotificationService] Requesting permissions...");
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      print("  -> Requesting standard notification permission...");
      final bool? standardResult =
          await androidImplementation.requestNotificationsPermission();
      print("  -> Standard permission result: $standardResult");

      print("  -> Requesting exact alarm permission...");
      final bool? exactResult =
          await androidImplementation.requestExactAlarmsPermission();
      print("  -> Exact alarm permission result: $exactResult");
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print("✅ [NotificationService] Permissions requested.");
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool isAlarm = false,
  }) async {
    final String type = isAlarm ? "ALARM" : "STANDARD";
    print("🔔 [NotificationService] Scheduling one-time $type notification...");
    print("  -> ID: $id, Title: $title, Time: $scheduledTime");
    if (isAlarm) {
      print(
          "  -> ❗ REMINDER: This is an ALARM. Ensure 'alarm.mp3' exists in android/app/src/main/res/raw/");
    }
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        isAlarm ? _alarmNotificationDetails : _standardNotificationDetails,
        androidScheduleMode: isAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("✅ [NotificationService] Successfully scheduled notification #$id");
    } catch (e) {
      print("❌ [NotificationService] ERROR scheduling notification #$id: $e");
    }
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    bool isAlarm = false,
  }) async {
    final String type = isAlarm ? "ALARM" : "STANDARD";
    print("🔔 [NotificationService] Scheduling daily $type notification...");
    print("  -> ID: $id, Title: $title, Time: ${time.hour}:${time.minute}");
    if (isAlarm) {
      print(
          "  -> ❗ REMINDER: This is an ALARM. Ensure 'alarm.mp3' exists in android/app/src/main/res/raw/");
    }
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        isAlarm ? _alarmNotificationDetails : _standardNotificationDetails,
        androidScheduleMode: isAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print(
          "✅ [NotificationService] Successfully scheduled daily notification #$id");
    } catch (e) {
      print(
          "❌ [NotificationService] ERROR scheduling daily notification #$id: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    print("🔔 [NotificationService] Cancelling notification #$id...");
    await flutterLocalNotificationsPlugin.cancel(id);
    print("✅ [NotificationService] Notification #$id cancelled.");
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
