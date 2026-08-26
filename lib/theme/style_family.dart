/// Six visual style families. Each has carefully designed light AND dark packs.
enum VisualStyleFamily {
  signature,
  naturalistic,
  softCute,
  neoBrutal,
  aurora,
  quietFocus,
}

extension VisualStyleFamilyX on VisualStyleFamily {
  String get id => name;

  String get label => switch (this) {
        VisualStyleFamily.signature => 'Signature / Editorial',
        VisualStyleFamily.naturalistic => 'Naturalistic / Biophilic',
        VisualStyleFamily.softCute => 'Soft / Cute',
        VisualStyleFamily.neoBrutal => 'Neo-Brutal / Bold',
        VisualStyleFamily.aurora => 'Aurora / Glass',
        VisualStyleFamily.quietFocus => 'Quiet Focus / Minimal',
      };

  String get subtitle => switch (this) {
        VisualStyleFamily.signature =>
          'Warm paper, forest ink, botanical lime — closest to the study coach feel',
        VisualStyleFamily.naturalistic =>
          'Moss, terracotta, greenhouse calm — pairs with Studio Garden plants',
        VisualStyleFamily.softCute =>
          'Rounded, soft hierarchy — cute only in non-critical feedback',
        VisualStyleFamily.neoBrutal =>
          'Hard borders, bold type, high-contrast blocks',
        VisualStyleFamily.aurora =>
          'Translucent layers with strong contrast for readable text',
        VisualStyleFamily.quietFocus =>
          'Spare surfaces, quiet ink, minimal decoration',
      };

  /// Runway / timeline motif for assessment page.
  String get runwayMotif => switch (this) {
        VisualStyleFamily.signature => 'timeline',
        VisualStyleFamily.naturalistic => 'vine',
        VisualStyleFamily.softCute => 'stones',
        VisualStyleFamily.neoBrutal => 'blocks',
        VisualStyleFamily.aurora => 'illuminated',
        VisualStyleFamily.quietFocus => 'line',
      };

  bool get usesPlantPhases =>
      this == VisualStyleFamily.naturalistic ||
      this == VisualStyleFamily.softCute;

  static VisualStyleFamily fromStorage(String? value) {
    return VisualStyleFamily.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VisualStyleFamily.signature,
    );
  }
}

enum ThemeBrightnessPref {
  light,
  dark,
  system,
}

extension ThemeBrightnessPrefX on ThemeBrightnessPref {
  String get label => switch (this) {
        ThemeBrightnessPref.light => 'Light',
        ThemeBrightnessPref.dark => 'Dark',
        ThemeBrightnessPref.system => 'System',
      };

  static ThemeBrightnessPref fromStorage(String? value) {
    return ThemeBrightnessPref.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ThemeBrightnessPref.dark,
    );
  }
}

enum SpacingDensity {
  comfortable,
  compact,
}

extension SpacingDensityX on SpacingDensity {
  String get label => switch (this) {
        SpacingDensity.comfortable => 'Comfortable',
        SpacingDensity.compact => 'Compact',
      };

  double get spaceUnit => switch (this) {
        SpacingDensity.comfortable => 8,
        SpacingDensity.compact => 6,
      };

  static SpacingDensity fromStorage(String? value) {
    return SpacingDensity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SpacingDensity.comfortable,
    );
  }
}

enum ContrastLevel {
  normal,
  increased,
}

extension ContrastLevelX on ContrastLevel {
  String get label => switch (this) {
        ContrastLevel.normal => 'Normal',
        ContrastLevel.increased => 'Increased',
      };

  static ContrastLevel fromStorage(String? value) {
    return ContrastLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ContrastLevel.normal,
    );
  }
}
