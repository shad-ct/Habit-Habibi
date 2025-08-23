// main.dart
// Main entry point for the Habit-Habibi application.

// --- UPDATE NOTES ---
// 1. Imported the new `timer_stopwatch_screen.dart`.
// 2. Added the `TimerStopwatchScreen` to the list of screens.
// 3. Added a new `BottomNavigationBarItem` for the new screen.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'habit_tracker_screen.dart';
import 'special_days_screen.dart';
import 'notification_service.dart';
import 'notification_scheduler.dart';
import 'todo_list_screen.dart';
import 'home_screen.dart';
import 'timer_stopwatch_screen.dart'; // New import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyASZh4tJPlAOHTKaS8MbAg1m2weCoPhYp0",
        authDomain: "habit-habibi.firebaseapp.com",
        projectId: "habit-habibi",
        storageBucket: "habit-habibi.firebasestorage.app",
        messagingSenderId: "212372510139",
        appId: "1:212372510139:web:68846e9882628edb3e609e",
        measurementId: "G-8B0RH4R9VB"),
  );

  await NotificationScheduler.scheduleAllHabitNotifications();

  Animate.restartOnHotReload = true;
  runApp(const HabitHabibiApp());
}

class HabitHabibiApp extends StatelessWidget {
  const HabitHabibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit-Habibi',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.teal.shade50,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal.shade400,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white.withOpacity(0.87),
                displayColor: Colors.white.withOpacity(0.87),
              ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal.shade300,
          foregroundColor: Colors.black,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // UPDATED: Added TimerStopwatchScreen
  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    HabitTrackerScreen(),
    SpecialDaysScreen(),
    TodoListScreen(),
    TimerStopwatchScreen(),
  ];

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: _screens,
        ),
      ),
      // UPDATED: Added new BottomNavigationBarItem
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake_outlined),
            activeIcon: Icon(Icons.cake),
            label: 'Special Days',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'To-Do',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            activeIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
