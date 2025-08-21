// notification_scheduler.dart
// This file handles scheduling notifications for all existing habits on app startup

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationScheduler {
  static Future<void> scheduleAllHabitNotifications() async {
    final firestore = FirebaseFirestore.instance;
    final notificationService = NotificationService();

    try {
      final habitsSnapshot = await firestore.collection('habits').get();

      for (final doc in habitsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Habit';
        final hour = data['reminderHour'] ?? 9;
        final minute = data['reminderMinute'] ?? 0;
        final isAlarm = data['isAlarm'] ?? false;

        final notificationId = doc.id.hashCode;

        await notificationService.scheduleDailyNotification(
          id: notificationId,
          title: 'Habit Reminder',
          body: 'Time to complete your habit: $name',
          time: TimeOfDay(hour: hour, minute: minute),
          isAlarm: isAlarm,
        );
      }

      print('✅ Scheduled ${habitsSnapshot.docs.length} habit notifications');
    } catch (e) {
      print('❌ Error scheduling notifications: $e');
    }
  }
}
