enum AppVisualMode {
  light,
  dark,
  blend,
}

extension AppVisualModeX on AppVisualMode {
  String get label => switch (this) {
        AppVisualMode.light => 'Light',
        AppVisualMode.dark => 'Dark',
        AppVisualMode.blend => 'Blend',
      };

  String get subtitle => switch (this) {
        AppVisualMode.light => 'Warm pastel greens & peach',
        AppVisualMode.dark => 'Deep forest greens',
        AppVisualMode.blend => 'Pull colours from your background',
      };

  static AppVisualMode fromStorage(String? value) {
    return AppVisualMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppVisualMode.dark,
    );
  }
}
