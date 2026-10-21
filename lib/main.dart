import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/app_services.dart';
import 'services/live_activity.dart';
import 'services/sounds.dart';
import 'services/workout_library.dart';
import 'services/workout_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final sounds = AssetSounds();
  unawaited(sounds.init());
  final notifications = LocalWorkoutNotifications();
  await notifications.init();
  final library = await LibraryStore().load();

  runApp(
    SpurtlyApp(
      library: library,
      services: AppServices(
        sounds: sounds,
        notifications: notifications,
        liveActivity: PlatformLiveActivity(),
      ),
    ),
  );
}
