// habit.dart
// Data model for a single habit. This class defines the structure
// of a habit, including its name, streak, and completion status.

class Habit {
  String name;
  int streak;
  bool isCompletedToday;

  Habit({required this.name, this.streak = 0, this.isCompletedToday = false});
}
