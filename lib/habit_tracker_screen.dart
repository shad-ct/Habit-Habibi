// habit_tracker_screen.dart
// This screen displays the list of daily habits from Firestore and allows
// full CRUD operations and schedules daily notifications.

import 'package:flutter/material.dart';
// FIXED: Corrected the import path for cloud_firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'habit_tile.dart';
import 'notification_service.dart';

class HabitTrackerScreen extends StatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  final CollectionReference _habits =
      FirebaseFirestore.instance.collection('habits');
  final NotificationService _notificationService = NotificationService();

  // --- CREATE OR UPDATE A HABIT ---
  Future<void> _createOrUpdate([DocumentSnapshot? documentSnapshot]) async {
    String action = 'create';
    bool isAlarm = false; // Default value for the alarm toggle
    if (documentSnapshot != null) {
      action = 'update';
      // Safely read the isAlarm field, defaulting to false if it doesn't exist
      final data = documentSnapshot.data() as Map<String, dynamic>?;
      isAlarm = data?.containsKey('isAlarm') ?? false
          ? documentSnapshot['isAlarm']
          : false;
    }

    final TextEditingController nameController = TextEditingController(
      text: documentSnapshot?['name'],
    );
    TimeOfDay selectedTime = TimeOfDay.now();

    if (action == 'update') {
      selectedTime = TimeOfDay(
        hour: documentSnapshot?['reminderHour'],
        minute: documentSnapshot?['reminderMinute'],
      );
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(action == 'create' ? 'Add a New Habit' : 'Edit Habit'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Habit Name'),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Enable Alarm'),
                    value: isAlarm,
                    onChanged: (bool value) {
                      setState(() {
                        isAlarm = value;
                      });
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Select Reminder Time'),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        selectedTime = picked;
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    final String name = nameController.text;
                    if (name.isNotEmpty) {
                      final data = {
                        "name": name,
                        "streak": documentSnapshot?['streak'] ?? 0,
                        "isCompletedToday":
                            documentSnapshot?['isCompletedToday'] ?? false,
                        "reminderHour": selectedTime.hour,
                        "reminderMinute": selectedTime.minute,
                        "isAlarm": isAlarm,
                      };

                      int notificationId;

                      if (action == 'create') {
                        final docRef = await _habits.add(data);
                        notificationId = docRef.id.hashCode;
                      } else {
                        await _habits.doc(documentSnapshot!.id).update(data);
                        notificationId = documentSnapshot.id.hashCode;
                      }

                      _notificationService.scheduleDailyNotification(
                        id: notificationId,
                        title: 'Habit Reminder',
                        body: 'Time to complete your habit: $name',
                        time: selectedTime,
                        isAlarm: isAlarm,
                      );

                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DELETE A HABIT ---
  Future<void> _deleteHabit(String habitId) async {
    await _habits.doc(habitId).delete();
    _notificationService.cancelNotification(habitId.hashCode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit successfully deleted')));
    }
  }

  // --- TOGGLE HABIT COMPLETION ---
  Future<void> _toggleCompletion(
    DocumentSnapshot habit,
    bool isCompleted,
  ) async {
    int currentStreak = habit['streak'];
    int newStreak = isCompleted ? currentStreak + 1 : 0;

    await _habits.doc(habit.id).update({
      'isCompletedToday': isCompleted,
      'streak': newStreak,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Your Habits',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _habits.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
          if (streamSnapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          if (streamSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!streamSnapshot.hasData || streamSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No habits found. Add one!'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: streamSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot documentSnapshot =
                  streamSnapshot.data!.docs[index];
              return HabitTile(
                documentSnapshot: documentSnapshot,
                onChanged: (value) {
                  _toggleCompletion(documentSnapshot, value ?? false);
                },
                onEdit: () => _createOrUpdate(documentSnapshot),
                onDelete: () => _deleteHabit(documentSnapshot.id),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                  .slideY(begin: 0.5, end: 0, curve: Curves.easeOut);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrUpdate(),
        tooltip: 'Add Habit',
        child: const Icon(Icons.add),
      ).animate().scale(delay: 300.ms),
    );
  }
}
