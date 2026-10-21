/// How the timer signals phase changes.
class AppSettings {
  const AppSettings({
    this.sounds = true,
    this.countdown = true,
    this.vibration = true,
  });

  /// Chimes at the start of work, rest and the finish.
  final bool sounds;

  /// Pips (and light taps, with [vibration]) in the last 3 seconds of a
  /// phase.
  final bool countdown;

  /// A strong tap when a phase changes, while the app is on screen.
  final bool vibration;

  AppSettings copyWith({bool? sounds, bool? countdown, bool? vibration}) {
    return AppSettings(
      sounds: sounds ?? this.sounds,
      countdown: countdown ?? this.countdown,
      vibration: vibration ?? this.vibration,
    );
  }

  Map<String, Object> toJson() => {
    'sounds': sounds,
    'countdown': countdown,
    'vibration': vibration,
  };

  factory AppSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const AppSettings();
    bool flag(String key) => json[key] is bool ? json[key]! as bool : true;
    return AppSettings(
      sounds: flag('sounds'),
      countdown: flag('countdown'),
      vibration: flag('vibration'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.sounds == sounds &&
      other.countdown == countdown &&
      other.vibration == vibration;

  @override
  int get hashCode => Object.hash(sounds, countdown, vibration);
}
