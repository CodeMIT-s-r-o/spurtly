# Spurtly

An interval timer for HIIT workouts: warm-up, then rounds of work and rest
intervals, with distinct sound cues and lock-screen notifications so it can
run with the phone locked on the floor.

- **App name:** Spurtly
- **Bundle ID:** `sk.codemit.spurtly` (iOS and Android)
- **Platforms:** iOS and Android (Flutter)

## Features

- **Workout setup:** warm-up, work, rest, intervals per round, rounds and an
  optional longer rest between rounds. The last setup is remembered.
- **Timer:** full-screen color per phase, countdown ring, round and interval
  position, what comes next, pause and skip.
- **Sound cues:** a rising chime when work starts, a falling chime when rest
  starts, a short arpeggio at the end and 3-2-1 pips before each phase ends.
  Cues mix with music from other apps instead of pausing it.
- **Locked screen:** the workout keeps running and cues keep playing. Each phase
  change updates a single notification on the lock screen and in Notification
  Center; it is removed when the app comes back to the foreground.

## Requirements

- Flutter stable (3.47 or newer)
- iOS: Xcode with the matching iOS platform installed
  (Xcode → Settings → Components)
- Android: Android SDK 36

## Getting started

```bash
flutter pub get
flutter run
```

Pick a device with `flutter devices` and `flutter run -d <device-id>`.

Checks:

```bash
flutter analyze
flutter test
```

## Project layout

```
lib/
  main.dart                 Startup: loads settings, audio and notifications
  app.dart                  MaterialApp and theme
  theme.dart                Colors per phase, formatting helpers
  models/                   WorkoutConfig (setup) and Phase (one timed segment)
  timer/workout_timer.dart  Runs the phases; time comes from a clock, not ticks
  screens/                  Setup screen and timer screen
  services/
    sounds.dart                 Cue playback and the background keep-alive loop
    workout_notifications.dart  Lock-screen notification
    config_store.dart           Saves the last setup
  widgets/stepper_row.dart  − / + row with hold-to-repeat
test/                       Timer logic and setup screen tests
tool/                       Scripts that generate the icon and sounds
assets/
  icon/                     App icon sources
  images/logo.png           Logo shown in the app header
  sounds/                   Cue WAVs
```

## Regenerating assets

The icon and sounds are generated, not drawn or recorded. The scripts need
Python 3 with NumPy and Pillow.

```bash
python3 tool/make_logo.py assets/icon assets/images
dart run flutter_launcher_icons
```

```bash
python3 tool/make_sounds.py assets/sounds
```

The launch screen color comes from the `flutter_native_splash` section in
`pubspec.yaml`; regenerate it with `dart run flutter_native_splash:create`.

## How the locked screen works

iOS suspends an app shortly after the screen locks. While a workout is running,
Spurtly plays a silent audio loop (`UIBackgroundModes: audio` in
`ios/Runner/Info.plist`), which keeps the app and its timer alive so cues still
play. The loop stops when the workout is paused or finished.

Apple may question apps that use background audio only to stay alive. An
interval timer that plays audible cues is a common, usually accepted case, but
keep it in mind for App Store review.

On Android the audio players hold a partial wake lock while playing
(`WAKE_LOCK` permission). This path has not been tested on a device yet.
