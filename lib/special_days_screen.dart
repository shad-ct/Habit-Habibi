// special_days_screen.dart
// This screen displays a list of special days from Firestore
// and allows users to add, edit, and delete them.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class SpecialDaysScreen extends StatefulWidget {
  const SpecialDaysScreen({super.key});

  @override
  State<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends State<SpecialDaysScreen> {
  final CollectionReference _specialDays =
      FirebaseFirestore.instance.collection('special_days');
  final NotificationService _notificationService = NotificationService();

  // --- CREATE OR UPDATE A SPECIAL DAY ---
  Future<void> _createOrUpdate([DocumentSnapshot? documentSnapshot]) async {
    String action = 'create';
    bool isAlarm = false;
    bool remindDayBefore = false;

    if (documentSnapshot != null) {
      action = 'update';
      final data = documentSnapshot.data() as Map<String, dynamic>?;
      isAlarm = data?.containsKey('isAlarm') ?? false
          ? documentSnapshot['isAlarm']
          : false;
      remindDayBefore = data?.containsKey('remindDayBefore') ?? false
          ? documentSnapshot['remindDayBefore']
          : false;
    }

    final TextEditingController nameController = TextEditingController(
      text: documentSnapshot?['name'],
    );
    final TextEditingController contactController = TextEditingController(
      text: documentSnapshot?['contact'],
    );
    DateTime selectedDate = documentSnapshot != null
        ? (documentSnapshot['date'] as Timestamp).toDate()
        : DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String eventType = documentSnapshot?['type'] ?? 'Birthday';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                action == 'create' ? 'Add a Special Day' : 'Edit Special Day',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Person\'s Name',
                      ),
                    ),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Info (Optional)',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: eventType,
                      items: ['Birthday', 'Anniversary', 'Other']
                          .map(
                            (label) => DropdownMenuItem(
                                child: Text(label), value: label),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) eventType = value;
                      },
                    ),
                    const SizedBox(height: 20),
                    // UPDATED: Added toggles for alarm and pre-reminder
                    SwitchListTile(
                      title: const Text('Enable Alarm'),
                      value: isAlarm,
                      onChanged: (bool value) {
                        setState(() => isAlarm = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Remind 1 day before'),
                      value: remindDayBefore,
                      onChanged: (bool value) {
                        setState(() => remindDayBefore = value);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          child: const Text('Select Date'),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null) selectedDate = picked;
                          },
                        ),
                        ElevatedButton(
                          child: const Text('Select Time'),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) selectedTime = picked;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    final String name = nameController.text;
                    if (name.isNotEmpty) {
                      final DateTime scheduledDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      final data = {
                        "name": name,
                        "contact": contactController.text,
                        "date": Timestamp.fromDate(scheduledDateTime),
                        "type": eventType,
                        "isAlarm": isAlarm,
                        "remindDayBefore": remindDayBefore,
                      };

                      String docId;
                      if (action == 'create') {
                        final docRef = await _specialDays.add(data);
                        docId = docRef.id;
                      } else {
                        docId = documentSnapshot!.id;
                        await _specialDays.doc(docId).update(data);
                      }

                      // Schedule the main notification
                      _notificationService.scheduleNotification(
                        id: docId.hashCode,
                        title: '$eventType Reminder!',
                        body:
                            'Today is ${name}\'s $eventType. Don\'t forget to reach out!',
                        scheduledTime: scheduledDateTime,
                        isAlarm: isAlarm,
                      );

                      // Schedule the pre-reminder if enabled
                      final preReminderId = (docId + "_pre").hashCode;
                      if (remindDayBefore) {
                        _notificationService.scheduleNotification(
                          id: preReminderId,
                          title: 'Upcoming $eventType',
                          body: 'Tomorrow is ${name}\'s $eventType!',
                          scheduledTime: scheduledDateTime
                              .subtract(const Duration(days: 1)),
                          isAlarm: false, // Pre-reminders are standard
                        );
                      } else {
                        // Cancel any existing pre-reminder if the option is turned off
                        _notificationService.cancelNotification(preReminderId);
                      }

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

  // --- DELETE A SPECIAL DAY ---
  Future<void> _deleteSpecialDay(String docId) async {
    await _specialDays.doc(docId).delete();
    // Cancel both the main notification and the potential pre-reminder
    _notificationService.cancelNotification(docId.hashCode);
    _notificationService.cancelNotification((docId + "_pre").hashCode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have successfully deleted a special day'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Special Days',
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
        stream: _specialDays.orderBy('date').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
          if (streamSnapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          if (streamSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!streamSnapshot.hasData || streamSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No special days found. Add one!'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: streamSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot documentSnapshot =
                  streamSnapshot.data!.docs[index];
              final DateTime date =
                  (documentSnapshot['date'] as Timestamp).toDate();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.cake, color: Colors.pinkAccent),
                  title: Text(
                    documentSnapshot['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${documentSnapshot['type']} on ${DateFormat.yMMMd().add_jm().format(date)}',
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _createOrUpdate(documentSnapshot),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deleteSpecialDay(documentSnapshot.id),
                        ),
                      ],
                    ),
                  ),
                ),
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
        tooltip: 'Add Special Day',
        child: const Icon(Icons.add),
      ).animate().scale(delay: 300.ms),
    );
  }
}
