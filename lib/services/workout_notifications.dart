import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the current phase on the lock screen and in Notification Center
/// while the workout runs in the background.
abstract interface class WorkoutNotifications {
  /// Asks for permission the first time; later calls return at once.
  Future<void> requestPermission();

  /// Shows [title] and [body], replacing whatever was shown before.
  Future<void> show(String title, String body);

  /// Removes the notification.
  Future<void> clear();
}

class LocalWorkoutNotifications implements WorkoutNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // A single id, so each phase replaces the previous notification instead of
  // stacking up in Notification Center.
  static const _id = 1;

  static const _details = NotificationDetails(
    // The app plays its own cue, so the notification itself stays silent.
    iOS: DarwinNotificationDetails(
      presentSound: false,
      threadIdentifier: 'workout',
    ),
    android: AndroidNotificationDetails(
      'workout',
      'Workout progress',
      channelDescription: 'Shows the current phase while the screen is off.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      category: AndroidNotificationCategory.workout,
      visibility: NotificationVisibility.public,
    ),
  );

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Permission is requested when the first workout starts instead.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          android: AndroidInitializationSettings(
            '@drawable/ic_launcher_monochrome',
          ),
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('Notification permission failed: $error');
    }
  }

  @override
  Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } catch (error) {
      debugPrint('Notification failed: $error');
    }
  }

  @override
  Future<void> clear() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (error) {
      debugPrint('Clearing notification failed: $error');
    }
  }
}
