import 'live_activity.dart';
import 'pro.dart';
import 'sounds.dart';
import 'workout_notifications.dart';

/// Platform services: what a running workout uses, and Spurtly Pro.
class AppServices {
  const AppServices({
    required this.sounds,
    required this.notifications,
    required this.liveActivity,
    required this.pro,
  });

  final Sounds sounds;
  final WorkoutNotifications notifications;
  final LiveActivity liveActivity;
  final SpurtlyPro pro;
}
