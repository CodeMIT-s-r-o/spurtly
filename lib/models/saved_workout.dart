import 'workout_config.dart';

/// A named workout the user can start, edit and keep.
class SavedWorkout {
  const SavedWorkout({
    required this.id,
    required this.name,
    required this.config,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final WorkoutConfig config;

  SavedWorkout copyWith({
    String? name,
    String? description,
    WorkoutConfig? config,
  }) {
    return SavedWorkout(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      config: config ?? this.config,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'config': config.toJson(),
  };

  /// Returns `null` for entries without an id, so one bad entry doesn't
  /// lose the rest of the list.
  static SavedWorkout? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final config = json['config'];
    return SavedWorkout(
      id: id,
      name: switch (json['name']) {
        final String name when name.trim().isNotEmpty => name,
        _ => 'Workout',
      },
      description: switch (json['description']) {
        final String description => description,
        _ => '',
      },
      config: config is Map<String, Object?>
          ? WorkoutConfig.fromJson(config)
          : WorkoutConfig.defaults,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedWorkout &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.config == config;

  @override
  int get hashCode => Object.hash(id, name, description, config);
}
