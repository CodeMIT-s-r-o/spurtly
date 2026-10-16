import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audible cues during a workout.
enum Cue {
  /// A work interval starts: bright, rising chime.
  work('sounds/work.wav'),

  /// A rest or round rest starts: soft, falling chime.
  rest('sounds/rest.wav'),

  /// The workout is complete: short arpeggio.
  finish('sounds/finish.wav'),

  /// One of the last three seconds of a phase: short pip.
  countdown('sounds/countdown.wav');

  const Cue(this.asset);

  final String asset;
}

abstract interface class Sounds {
  Future<void> play(Cue cue);

  /// While [active], keeps the app's audio session playing so the workout
  /// keeps running, and cues keep playing, with the screen locked.
  Future<void> keepAlive(bool active);
}

/// Plays [Cue]s from the app's assets, one preloaded player per cue so a
/// countdown pip never cuts off the chime before it.
class AssetSounds implements Sounds {
  final Map<Cue, AudioPlayer> _players = {};
  final AudioPlayer _silence = AudioPlayer(playerId: 'keep-alive');

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // Playback continues in the background (UIBackgroundModes: audio)
          // and mixes with the user's music instead of pausing it.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await _silence.setReleaseMode(ReleaseMode.loop);
      await _silence.setSource(AssetSource('sounds/silence.wav'));
    } catch (error) {
      debugPrint('Audio context not set: $error');
    }
    for (final cue in Cue.values) {
      final player = AudioPlayer(playerId: 'cue-${cue.name}');
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(cue.asset));
        _players[cue] = player;
      } catch (error) {
        debugPrint('Sound ${cue.name} unavailable: $error');
        await player.dispose();
      }
    }
  }

  @override
  Future<void> play(Cue cue) async {
    // Missing players mean the asset failed to load; stay silent rather than
    // waiting on a player that has nothing to play.
    final player = _players[cue];
    if (player == null) return;
    try {
      // Restart from the beginning even if the last play is still fading.
      await player.seek(Duration.zero);
      await player.resume();
    } catch (error) {
      debugPrint('Sound ${cue.name} failed: $error');
    }
  }

  /// iOS suspends a backgrounded app unless it is playing audio, so a silent
  /// loop runs for as long as the workout does.
  @override
  Future<void> keepAlive(bool active) async {
    try {
      active ? await _silence.resume() : await _silence.pause();
    } catch (error) {
      debugPrint('Keep-alive failed: $error');
    }
  }
}
