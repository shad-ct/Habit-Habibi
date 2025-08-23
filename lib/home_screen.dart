// home_screen.dart
// Android-optimized home page with larger vertical calendar displays

// --- FIX NOTES ---
// 1. Rewrote the `_buildStreakCalendar` widget logic completely.
// 2. The calendar now correctly infers historical completion data based on
//    each habit's 'streak' and 'isCompletedToday' status.
// 3. The color of each day now represents the percentage of habits completed
//    on that day, giving a much more accurate and useful visualization.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'glassmorphic_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _quote = "Loading your daily motivation...";
  String _author = "";
  bool _isLoadingQuote = true;
  final CollectionReference _habits =
      FirebaseFirestore.instance.collection('habits');

  @override
  void initState() {
    super.initState();
    _fetchDailyQuote();
  }

  Future<void> _fetchDailyQuote() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.api-ninjas.com/v1/quotes?category=success'),
        headers: {
          'X-Api-Key': 'mOmuN/Y623xFWK6iRtLmdQ==Rwn9YNRPX62bbO0J',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _quote = data[0]['quote'];
            _author = data[0]['author'];
            _isLoadingQuote = false;
          });
        }
      } else {
        throw Exception('Failed to load quote');
      }
    } catch (e) {
      setState(() {
        _quote = "Every small step counts towards your goals.";
        _author = "Habit Habibi";
        _isLoadingQuote = false;
      });
    }
  }

  // --- UPDATED WIDGET ---
  Widget _buildStreakCalendar(List<DocumentSnapshot> habits, bool isWeekly) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysToShow = isWeekly ? 7 : 30;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWeekly ? 'Weekly Progress' : 'Monthly Progress',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: daysToShow,
                itemBuilder: (context, index) {
                  final date =
                      today.subtract(Duration(days: daysToShow - 1 - index));
                  final dayName = isWeekly
                      ? ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1]
                      : date.day.toString();

                  final daysAgo = today.difference(date).inDays;

                  int completedHabitsForThisDay = 0;
                  if (habits.isNotEmpty) {
                    for (var habit in habits) {
                      final data = habit.data() as Map<String, dynamic>;
                      final streak = data['streak'] as int? ?? 0;
                      final isCompletedToday =
                          data['isCompletedToday'] as bool? ?? false;

                      if (isCompletedToday) {
                        if (daysAgo < streak) {
                          completedHabitsForThisDay++;
                        }
                      } else {
                        if (daysAgo > 0 && daysAgo <= streak) {
                          completedHabitsForThisDay++;
                        }
                      }
                    }
                  }

                  final completionRatio = habits.isEmpty
                      ? 0.0
                      : completedHabitsForThisDay / habits.length;

                  final color = Color.lerp(
                    theme.colorScheme.surfaceVariant,
                    theme.colorScheme.primary,
                    completionRatio,
                  )!;

                  final onColor = completionRatio > 0.6
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface;

                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _habits.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading habits',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              );
            }

            final habits = snapshot.data?.docs ?? [];
            final totalStreakDays = habits.fold(0, (sum, habit) {
              final data = habit.data() as Map<String, dynamic>?;
              return sum + (data?['streak'] as int? ?? 0);
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome header
                  GlassmorphicContainer(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep building your habits',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Daily quote
                  GlassmorphicContainer(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Daily Motivation',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _quote,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (_author.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '- $_author',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress overview
                  GlassmorphicContainer(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$totalStreakDays',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Total Streak Days',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildStreakCalendar(habits, true),
                          const SizedBox(height: 20),
                          _buildStreakCalendar(habits, false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
