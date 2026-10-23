import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/app_services.dart';
import 'services/live_activity.dart';
import 'services/pro.dart';
import 'services/sounds.dart';
import 'services/workout_library.dart';
import 'services/workout_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait from the first frame on phones; the app unlocks rotation on
  // tablets (see SpurtlyApp).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final sounds = AssetSounds();
  unawaited(sounds.init());
  final notifications = LocalWorkoutNotifications();
  await notifications.init();
  final library = await LibraryStore().load();
  final pro = StorePro();
  await pro.load();

  runApp(
    SpurtlyApp(
      library: library,
      services: AppServices(
        sounds: sounds,
        notifications: notifications,
        liveActivity: PlatformLiveActivity(),
        pro: pro,
      ),
    ),
  );
}
