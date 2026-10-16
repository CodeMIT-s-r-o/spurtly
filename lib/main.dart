import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/config_store.dart';
import 'services/sounds.dart';
import 'services/workout_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final store = ConfigStore();
  final sounds = AssetSounds();
  unawaited(sounds.init());
  final notifications = LocalWorkoutNotifications();
  await notifications.init();
  final config = await store.load();

  runApp(
    SpurtlyApp(
      initialConfig: config,
      onConfigChanged: store.save,
      sounds: sounds,
      notifications: notifications,
    ),
  );
}
