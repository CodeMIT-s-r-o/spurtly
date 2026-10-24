import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sounds.dart';

/// Vibrates along with the cues, so a phase change can be felt with the
/// phone in a pocket or on the floor, also with the screen locked.
abstract interface class Vibrations {
  /// A pattern per cue: two pulses for work, one long one for rest, a tick
  /// for each of the last three seconds and a longer pattern at the finish.
  Future<void> vibrate(Cue cue);
}

/// Real vibrations through the platform (`spurtly/vibration`): the
/// vibration motor on Android, the system vibration on iPhone. Flutter's
/// `HapticFeedback` only gives a light tap, and only while the app is on
/// screen.
class PlatformVibrations implements Vibrations {
  static const _channel = MethodChannel('spurtly/vibration');

  @override
  Future<void> vibrate(Cue cue) async {
    try {
      await _channel.invokeMethod<void>('vibrate', cue.name);
    } on MissingPluginException {
      // Not on iOS or Android.
    } catch (error) {
      debugPrint('Vibration failed: $error');
    }
  }
}
