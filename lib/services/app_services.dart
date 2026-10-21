import 'live_activity.dart';
import 'sounds.dart';
import 'workout_notifications.dart';

/// Platform services a workout uses while it runs.
class AppServices {
  const AppServices({
    required this.sounds,
    required this.notifications,
    required this.liveActivity,
  });

  final Sounds sounds;
  final WorkoutNotifications notifications;
  final LiveActivity liveActivity;
}
