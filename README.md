# Spurtly

An interval timer for HIIT workouts: warm-up, then rounds of work and rest
intervals, with distinct sound cues and lock-screen notifications so it can
run with the phone locked on the floor.

- **App name:** Spurtly
- **Bundle ID:** `sk.codemit.spurtly` (iOS and Android)
- **Platforms:** iOS and Android (Flutter)

## Features

- **Saved workouts:** start from three presets (HIIT 1:1, HIIT 2:1, Tabata),
  edit them, restore them, or create, rename and delete your own. Each workout
  has a warm-up, work, rest, intervals per round, rounds and an optional
  longer rest between rounds. Start one straight from the list with its play
  button.
- **Timer:** full-screen color per phase, countdown ring, round and interval
  position, what comes next, pause and skip.
- **Sound cues:** a rising chime when work starts, a falling chime when rest
  starts, a short arpeggio at the end and 3-2-1 pips before each phase ends.
  Cues mix with music from other apps instead of pausing it. Sounds, the
  countdown and a vibration on phase changes can each be turned off in
  Settings.
- **Done screen:** the actual workout time, without pauses or skipped phases.
- **Live Activity (iOS 17+):** the current phase, a live countdown and its
  progress on the lock screen and in the Dynamic Island, with **Pause/Resume**
  and **Skip** buttons that control the timer without opening the app.
- **Locked screen:** the workout keeps running and cues keep playing. Where Live
  Activities are not available (older iOS, turned off, Android), each phase
  change updates a single notification instead; it is removed when the app
  comes back to the foreground.

## Requirements

- Flutter stable (3.47 or newer)
- iOS: Xcode with the matching iOS platform installed
  (Xcode → Settings → Components). Building for a device needs a signing team
  for both the `Runner` and `SpurtlyLiveActivity` targets.
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
  models/                   WorkoutConfig, SavedWorkout, presets, AppSettings
                            and Phase (one timed segment)
  timer/workout_timer.dart  Runs the phases; time comes from a clock, not ticks
  screens/                  Workout list, workout editor, settings and timer
  timer/phase_text.dart     "Round 2 / 3", "Next: Rest · 0:15" and similar texts
  services/
    sounds.dart                 Cue playback and the background keep-alive loop
    live_activity.dart          Live Activity state and its method channel
    workout_notifications.dart  Fallback lock-screen notification
    workout_library.dart        Saved workouts and settings, stored as JSON
  widgets/stepper_row.dart  − / + row with hold-to-repeat
ios/
  Runner/LiveActivityChannel.swift  Starts/updates/ends the activity for Dart
  Shared/SpurtlyActivity.swift      Activity data and the button intents,
                                    compiled into the app and the extension
  SpurtlyLiveActivity/              Widget extension that draws the activity
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

## How the Live Activity works

Dart sends the phase, its start and end time and whether it is paused over the
`spurtly/live_activity` method channel. The activity counts down by itself, so
it is only updated when the phase or the paused state changes.

With the screen on, iOS sweeps the progress bar smoothly. In the dimmed
Always-On state it redraws only once a second, so the bar is hidden there and
the countdown carries the time. A new phase cross-fades in: the card blends to
the next phase's color and the full bar fades in over the empty one.

The Pause/Resume and Skip buttons are `LiveActivityIntent`s. iOS runs them in
the app's process, where `LiveActivityChannel` forwards them to Dart. While the
activity is showing, the app stays alive even when paused, so Resume works from
the lock screen.

## How the locked screen works

iOS suspends an app shortly after the screen locks. While a workout is running,
Spurtly plays a silent audio loop (`UIBackgroundModes: audio` in
`ios/Runner/Info.plist`), which keeps the app and its timer alive so cues still
play. The loop stops when the workout finishes, or when it is paused and no
Live Activity is showing.

Apple may question apps that use background audio only to stay alive. An
interval timer that plays audible cues is a common, usually accepted case, but
keep it in mind for App Store review.

On Android the audio players hold a partial wake lock while playing
(`WAKE_LOCK` permission). This path has not been tested on a device yet.
