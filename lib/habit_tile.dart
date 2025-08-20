// habit_tile.dart
// A custom widget to display a single habit from Firestore in the list.
// It includes the habit name, streak, time, and CRUD controls.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'glassmorphic_container.dart'; // Import the new container

class HabitTile extends StatelessWidget {
  final DocumentSnapshot documentSnapshot;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitTile({
    super.key,
    required this.documentSnapshot,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = documentSnapshot['isCompletedToday'];
    final TimeOfDay reminderTime = TimeOfDay(
      hour: documentSnapshot['reminderHour'],
      minute: documentSnapshot['reminderMinute'],
    );
    final theme = Theme.of(context);

    // UPDATED: Replaced Card with our custom GlassmorphicContainer
    return GlassmorphicContainer(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: isCompleted,
          onChanged: onChanged,
          activeColor: theme.primaryColor,
          // UPDATED: Added a smooth animation for the checkbox
          side: BorderSide(color: theme.textTheme.bodyMedium!.color!, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          documentSnapshot['name'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration:
                isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
            color: isCompleted
                ? theme.textTheme.bodyMedium!.color!.withOpacity(0.5)
                : theme.textTheme.bodyMedium!.color,
          ),
        ),
        subtitle: Text(
          'Streak: ${documentSnapshot['streak']} days 🔥 | Reminder: ${reminderTime.format(context)}',
          style: TextStyle(
            color: isCompleted
                ? theme.textTheme.bodyMedium!.color!.withOpacity(0.4)
                : theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
          ),
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}
