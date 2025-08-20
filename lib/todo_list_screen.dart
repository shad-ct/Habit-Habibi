// todo_list_screen.dart
// A screen that mimics the functionality of Google Tasks, allowing users
// to manage a to-do list with Firebase integration and notifications.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'glassmorphic_container.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final CollectionReference _tasks =
      FirebaseFirestore.instance.collection('tasks');
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _taskController = TextEditingController();

  // --- ADD A NEW TASK ---
  Future<void> _addTask() async {
    if (_taskController.text.isNotEmpty) {
      await _tasks.add({
        'title': _taskController.text,
        'isCompleted': false,
        'dueDate': null,
        'createdAt': Timestamp.now(),
        'isAlarm': false, // Add default alarm state
      });
      _taskController.clear();
    }
  }

  // --- TOGGLE TASK COMPLETION ---
  Future<void> _toggleCompletion(DocumentSnapshot task) async {
    await _tasks.doc(task.id).update({'isCompleted': !task['isCompleted']});
  }

  // --- DELETE A TASK ---
  Future<void> _deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
    _notificationService.cancelNotification(taskId.hashCode);
  }

  // --- EDIT TASK TITLE ---
  Future<void> _editTitle(DocumentSnapshot task) async {
    _taskController.text = task['title'];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(controller: _taskController, autofocus: true),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              _taskController.clear();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              final newTitle = _taskController.text;
              await _tasks.doc(task.id).update({'title': newTitle});

              if (task['dueDate'] != null) {
                final data = task.data() as Map<String, dynamic>?;
                final isAlarm = data?.containsKey('isAlarm') ?? false
                    ? task['isAlarm']
                    : false;
                // FIXED: Reschedule with named parameters
                _notificationService.scheduleNotification(
                  id: task.id.hashCode,
                  title: 'To-Do Reminder',
                  body: 'Don\'t forget: $newTitle',
                  scheduledTime: task['dueDate'].toDate(),
                  isAlarm: isAlarm,
                );
              }
              _taskController.clear();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // --- SET DUE DATE AND SCHEDULE NOTIFICATION ---
  Future<void> _setDueDate(DocumentSnapshot task) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: task['dueDate']?.toDate() ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          task['dueDate']?.toDate() ?? DateTime.now(),
        ),
      );

      if (pickedTime != null) {
        final DateTime scheduledDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // UPDATED: Show dialog to set alarm
        bool isAlarm = false;
        final data = task.data() as Map<String, dynamic>?;
        isAlarm =
            data?.containsKey('isAlarm') ?? false ? task['isAlarm'] : false;

        await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Set Reminder Options'),
                  content: SwitchListTile(
                    title: const Text('Enable Alarm'),
                    value: isAlarm,
                    onChanged: (value) => setState(() => isAlarm = value),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Save'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                );
              });
            });

        await _tasks.doc(task.id).update({
          'dueDate': Timestamp.fromDate(scheduledDateTime),
          'isAlarm': isAlarm,
        });

        // FIXED: Schedule with named parameters
        _notificationService.scheduleNotification(
          id: task.id.hashCode,
          title: 'To-Do Reminder',
          body: 'Don\'t forget: ${task['title']}',
          scheduledTime: scheduledDateTime,
          isAlarm: isAlarm,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Your Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _tasks.orderBy('createdAt').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No tasks found. Add one!'));
              }

              final tasks = snapshot.data!.docs;
              final activeTasks =
                  tasks.where((t) => !t['isCompleted']).toList();
              final completedTasks =
                  tasks.where((t) => t['isCompleted']).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  ...activeTasks
                      .map((task) => _buildTaskTile(task))
                      .toList()
                      .animate(interval: 100.ms)
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: -0.2),
                  if (completedTasks.isNotEmpty)
                    ExpansionTile(
                      title: Text('Completed (${completedTasks.length})'),
                      children: completedTasks
                          .map((task) => _buildTaskTile(task))
                          .toList(),
                    ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildAddTaskBar().animate().slideY(
                  begin: 2,
                  end: 0,
                  delay: 300.ms,
                  curve: Curves.easeOut,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(DocumentSnapshot task) {
    final data = task.data() as Map<String, dynamic>?;
    final bool isAlarm =
        data?.containsKey('isAlarm') ?? false ? task['isAlarm'] : false;

    return ListTile(
      leading: Checkbox(
        value: task['isCompleted'],
        onChanged: (_) => _toggleCompletion(task),
      ),
      title: GestureDetector(
        onTap: () => _editTitle(task),
        child: Row(
          children: [
            Expanded(
              child: Text(
                task['title'],
                style: TextStyle(
                  decoration: task['isCompleted']
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            if (task['dueDate'] != null && isAlarm)
              const Icon(Icons.alarm, size: 16, color: Colors.grey),
          ],
        ),
      ),
      subtitle: task['dueDate'] != null
          ? Text(
              'Due: ${DateFormat.yMMMd().add_jm().format(task['dueDate'].toDate())}',
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: () => _setDueDate(task),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            onPressed: () => _deleteTask(task.id),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskBar() {
    return GlassmorphicContainer(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _taskController,
              decoration: const InputDecoration.collapsed(
                hintText: 'Add a new task...',
              ),
              onSubmitted: (_) => _addTask(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, size: 30),
            onPressed: _addTask,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
