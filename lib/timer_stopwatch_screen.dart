// timer_stopwatch_screen.dart
// A new screen featuring a stopwatch and a countdown timer.

// --- UPDATE NOTES ---
// 1. Modified the timer completion notification to be scheduled for 3 seconds
//    in the future using the timezone-aware `TZDateTime.now()`. This bypasses
//    potential issues with an incorrect device clock and makes testing immediate.
// 2. Added the necessary import for the 'timezone' package.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timezone/timezone.dart' as tz; // Added import
import 'glassmorphic_container.dart';
import 'notification_service.dart';

class TimerStopwatchScreen extends StatefulWidget {
  const TimerStopwatchScreen({super.key});

  @override
  State<TimerStopwatchScreen> createState() => _TimerStopwatchScreenState();
}

class _TimerStopwatchScreenState extends State<TimerStopwatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Timer & Stopwatch',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.timer_outlined), text: 'Timer'),
            Tab(icon: Icon(Icons.watch_later_outlined), text: 'Stopwatch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TimerView(),
          StopwatchView(),
        ],
      ),
    );
  }
}

// --- STOPWATCH WIDGET ---
class StopwatchView extends StatefulWidget {
  const StopwatchView({super.key});

  @override
  State<StopwatchView> createState() => _StopwatchViewState();
}

class _StopwatchViewState extends State<StopwatchView> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _displayTime = '00:00:00.000';
  final List<String> _laps = [];

  void _startStop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    } else {
      _stopwatch.start();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_stopwatch.isRunning) {
        timer.cancel();
      }
      if (mounted) {
        setState(() {
          _displayTime = _formatTime(_stopwatch.elapsed);
        });
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _reset() {
    _timer?.cancel();
    _stopwatch.reset();
    _stopwatch.stop();
    if (mounted) {
      setState(() {
        _displayTime = '00:00:00.000';
        _laps.clear();
      });
    }
  }

  void _lap() {
    if (_stopwatch.isRunning) {
      if (mounted) {
        setState(() {
          _laps.insert(
              0, '${_laps.length + 1}. ${_formatTime(_stopwatch.elapsed)}');
        });
      }
    }
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String threeDigitMilliseconds =
        threeDigits(duration.inMilliseconds.remainder(1000));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds.$threeDigitMilliseconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassmorphicContainer(
            margin: EdgeInsets.zero,
            child: Text(
              _displayTime,
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.refresh,
                onPressed: _reset,
              ),
              _buildControlButton(
                icon: _stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                isPrimary: true,
                onPressed: _startStop,
              ),
              _buildControlButton(
                icon: Icons.flag,
                onPressed: _lap,
              ),
            ],
          ).animate().slideY(begin: 1, duration: 400.ms),
          const SizedBox(height: 20),
          Expanded(
            child: GlassmorphicContainer(
              margin: EdgeInsets.zero,
              child: _laps.isEmpty
                  ? const Center(child: Text('Laps will appear here'))
                  : ListView.builder(
                      itemCount: _laps.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: Text(
                            _laps[index],
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TIMER WIDGET ---
class TimerView extends StatefulWidget {
  const TimerView({super.key});

  @override
  State<TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends State<TimerView> {
  Duration _duration = const Duration(minutes: 5);
  Duration _remaining = const Duration(minutes: 5);
  Timer? _timer;
  bool _isRunning = false;
  final NotificationService _notificationService = NotificationService();

  void _startPause() {
    if (_isRunning) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    } else {
      if (_remaining.inSeconds == 0) {
        _remaining = _duration;
      }
      if (mounted) {
        setState(() {
          _isRunning = true;
        });
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remaining.inSeconds <= 0) {
          timer.cancel();
          // FIXED: Schedule the notification for 3 seconds in the future
          // to ensure it appears immediately for testing.
          _notificationService.scheduleNotification(
            id: 999, // A unique ID for the timer notification
            title: 'Timer Finished!',
            body: 'Your ${_formatDuration(_duration)} timer is complete.',
            scheduledTime:
                tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3)),
            isAlarm: true, // This triggers the loud alarm sound
          );
          if (mounted) {
            setState(() {
              _isRunning = false;
              _remaining = _duration;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _remaining = _remaining - const Duration(seconds: 1);
            });
          }
        }
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _remaining = _duration;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassmorphicContainer(
            margin: EdgeInsets.zero,
            child: _isRunning || _remaining != _duration
                ? Text(
                    _formatDuration(_remaining),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  )
                : SizedBox(
                    height: 150,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hms,
                      initialTimerDuration: _duration,
                      onTimerDurationChanged: (Duration newDuration) {
                        if (mounted) {
                          setState(() {
                            _duration = newDuration;
                            _remaining = newDuration;
                          });
                        }
                      },
                    ),
                  ),
          ).animate().fadeIn(),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.refresh,
                onPressed: _reset,
              ),
              _buildControlButton(
                icon: _isRunning ? Icons.pause : Icons.play_arrow,
                isPrimary: true,
                onPressed: _startPause,
              ),
            ],
          ).animate().slideY(begin: 1, duration: 400.ms),
        ],
      ),
    );
  }
}

// --- SHARED UI WIDGETS ---
Widget _buildControlButton({
  required IconData icon,
  required VoidCallback onPressed,
  bool isPrimary = false,
}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(24),
        backgroundColor:
            isPrimary ? theme.colorScheme.primary : theme.colorScheme.surface,
        foregroundColor: isPrimary
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
      child: Icon(icon, size: 32),
    );
  });
}
