import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/background_assets.dart';
import 'app_theme_builder.dart';
import 'app_visual_mode.dart';
import 'style_family.dart';

/// Persists appearance locally and optionally to Firestore when [uid] is set.
class ThemeController extends ChangeNotifier {
  ThemeController();

  static const _styleKey = 'visual_style';
  static const _brightnessKey = 'theme_brightness';
  static const _motionKey = 'reduced_motion';
  static const _contrastKey = 'contrast_level';
  static const _spacingKey = 'spacing_density';
  static const _modeKey = 'visual_mode'; // legacy
  static const _bgKey = 'dashboard_background';
  static const _useBgBlendKey = 'use_bg_blend';

  VisualStyleFamily style = VisualStyleFamily.signature;
  ThemeBrightnessPref brightnessPref = ThemeBrightnessPref.dark;
  bool reducedMotion = false;
  ContrastLevel contrast = ContrastLevel.normal;
  SpacingDensity spacing = SpacingDensity.comfortable;
  String backgroundAsset = kDefaultBackgroundAsset;
  bool useBackgroundBlend = false;
  ColorScheme? _blendScheme;
  bool ready = false;
  String? _uid;

  /// Legacy accessor used by older UI.
  AppVisualMode get mode {
    if (useBackgroundBlend) return AppVisualMode.blend;
    return brightnessPref == ThemeBrightnessPref.light
        ? AppVisualMode.light
        : AppVisualMode.dark;
  }

  bool get needsDensePanels =>
      resolvedBrightness == Brightness.light || useBackgroundBlend;

  bool get showShellBackground =>
      useBackgroundBlend || style == VisualStyleFamily.naturalistic;

  Brightness get resolvedBrightness {
    if (useBackgroundBlend && _blendScheme != null) {
      return _blendScheme!.brightness;
    }
    switch (brightnessPref) {
      case ThemeBrightnessPref.light:
        return Brightness.light;
      case ThemeBrightnessPref.dark:
        return Brightness.dark;
      case ThemeBrightnessPref.system:
        return SchedulerBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  ThemeData get theme {
    final dark = resolvedBrightness == Brightness.dark;
    return AppThemeBuilder.build(
      family: style,
      dark: dark,
      spacing: spacing,
      contrast: contrast,
      reducedMotion: reducedMotion,
    );
  }

  ThemeData get lightTheme => AppThemeBuilder.build(
        family: style,
        dark: false,
        spacing: spacing,
        contrast: contrast,
        reducedMotion: reducedMotion,
      );

  ThemeData get darkTheme => AppThemeBuilder.build(
        family: style,
        dark: true,
        spacing: spacing,
        contrast: contrast,
        reducedMotion: reducedMotion,
      );

  ThemeMode get themeMode {
    if (useBackgroundBlend) {
      return resolvedBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    }
    return switch (brightnessPref) {
      ThemeBrightnessPref.light => ThemeMode.light,
      ThemeBrightnessPref.dark => ThemeMode.dark,
      ThemeBrightnessPref.system => ThemeMode.system,
    };
  }

  void bindUser(String? uid) {
    _uid = uid;
    if (uid != null) {
      _loadRemote(uid);
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy visual_mode if new keys absent.
    final legacyMode = prefs.getString(_modeKey);
    if (prefs.getString(_styleKey) == null && legacyMode != null) {
      final old = AppVisualModeX.fromStorage(legacyMode);
      style = VisualStyleFamily.signature;
      switch (old) {
        case AppVisualMode.light:
          brightnessPref = ThemeBrightnessPref.light;
          useBackgroundBlend = false;
        case AppVisualMode.dark:
          brightnessPref = ThemeBrightnessPref.dark;
          useBackgroundBlend = false;
        case AppVisualMode.blend:
          brightnessPref = ThemeBrightnessPref.system;
          useBackgroundBlend = true;
      }
    } else {
      style = VisualStyleFamilyX.fromStorage(prefs.getString(_styleKey));
      brightnessPref =
          ThemeBrightnessPrefX.fromStorage(prefs.getString(_brightnessKey));
      useBackgroundBlend = prefs.getBool(_useBgBlendKey) ?? false;
    }

    reducedMotion = prefs.getBool(_motionKey) ?? false;
    contrast = ContrastLevelX.fromStorage(prefs.getString(_contrastKey));
    spacing = SpacingDensityX.fromStorage(prefs.getString(_spacingKey));

    final savedBg = prefs.getString(_bgKey);
    if (savedBg != null && dashboardBackgroundAssets.contains(savedBg)) {
      backgroundAsset = savedBg;
    } else {
      backgroundAsset = kDefaultBackgroundAsset;
    }

    if (useBackgroundBlend) {
      await _extractBlendPalette();
    }

    ready = true;
    notifyListeners();
  }

  Future<void> setStyle(VisualStyleFamily next) async {
    style = next;
    await _persist();
    notifyListeners();
  }

  Future<void> setBrightnessPref(ThemeBrightnessPref next) async {
    brightnessPref = next;
    useBackgroundBlend = false;
    await _persist();
    notifyListeners();
  }

  Future<void> setReducedMotion(bool value) async {
    reducedMotion = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setContrast(ContrastLevel next) async {
    contrast = next;
    await _persist();
    notifyListeners();
  }

  Future<void> setSpacing(SpacingDensity next) async {
    spacing = next;
    await _persist();
    notifyListeners();
  }

  /// Legacy API preserved for existing call sites.
  Future<void> setMode(AppVisualMode next) async {
    switch (next) {
      case AppVisualMode.light:
        brightnessPref = ThemeBrightnessPref.light;
        useBackgroundBlend = false;
      case AppVisualMode.dark:
        brightnessPref = ThemeBrightnessPref.dark;
        useBackgroundBlend = false;
      case AppVisualMode.blend:
        useBackgroundBlend = true;
        await _extractBlendPalette();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setUseBackgroundBlend(bool value) async {
    useBackgroundBlend = value;
    if (value) await _extractBlendPalette();
    await _persist();
    notifyListeners();
  }

  Future<void> setBackground(String asset) async {
    if (!dashboardBackgroundAssets.contains(asset)) return;
    backgroundAsset = asset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgKey, asset);
    if (useBackgroundBlend) {
      await _extractBlendPalette();
    }
    await _persistRemote();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.name);
    await prefs.setString(_brightnessKey, brightnessPref.name);
    await prefs.setBool(_motionKey, reducedMotion);
    await prefs.setString(_contrastKey, contrast.name);
    await prefs.setString(_spacingKey, spacing.name);
    await prefs.setBool(_useBgBlendKey, useBackgroundBlend);
    await prefs.setString(_bgKey, backgroundAsset);
    // Keep legacy key in sync for older builds.
    await prefs.setString(_modeKey, mode.name);
    await _persistRemote();
  }

  Future<void> _persistRemote() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || uid == 'NO_USER') return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'appearance': {
          'style': style.name,
          'brightness': brightnessPref.name,
          'reducedMotion': reducedMotion,
          'contrast': contrast.name,
          'spacing': spacing.name,
          'useBackgroundBlend': useBackgroundBlend,
          'backgroundAsset': backgroundAsset,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Local prefs remain source of truth if remote fails.
    }
  }

  Future<void> _loadRemote(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final appearance = doc.data()?['appearance'] as Map<String, dynamic>?;
      if (appearance == null) return;

      style = VisualStyleFamilyX.fromStorage(appearance['style'] as String?);
      brightnessPref = ThemeBrightnessPrefX.fromStorage(
        appearance['brightness'] as String?,
      );
      reducedMotion = appearance['reducedMotion'] as bool? ?? reducedMotion;
      contrast =
          ContrastLevelX.fromStorage(appearance['contrast'] as String?);
      spacing = SpacingDensityX.fromStorage(appearance['spacing'] as String?);
      useBackgroundBlend =
          appearance['useBackgroundBlend'] as bool? ?? useBackgroundBlend;
      final bg = appearance['backgroundAsset'] as String?;
      if (bg != null && dashboardBackgroundAssets.contains(bg)) {
        backgroundAsset = bg;
      }
      if (useBackgroundBlend) await _extractBlendPalette();
      await _persist();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _extractBlendPalette() async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        AssetImage(backgroundAsset),
        size: const Size(160, 160),
        maximumColorCount: 12,
      );

      final samples = <Color>[
        if (palette.dominantColor != null) palette.dominantColor!.color,
        if (palette.vibrantColor != null) palette.vibrantColor!.color,
        if (palette.mutedColor != null) palette.mutedColor!.color,
        if (palette.lightMutedColor != null) palette.lightMutedColor!.color,
        if (palette.darkMutedColor != null) palette.darkMutedColor!.color,
        if (palette.lightVibrantColor != null) palette.lightVibrantColor!.color,
        if (palette.darkVibrantColor != null) palette.darkVibrantColor!.color,
      ];
      if (samples.isEmpty) samples.add(const Color(0xFF1C6E52));

      final avgLum = samples
              .map((c) => c.computeLuminance())
              .reduce((a, b) => a + b) /
          samples.length;

      final isDark = avgLum < 0.48;
      final dominant = palette.dominantColor?.color ?? samples.first;
      final vibrant = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          dominant;
      final muted = palette.mutedColor?.color ??
          palette.lightMutedColor?.color ??
          dominant;

      final surface = Color.lerp(
            dominant,
            isDark ? const Color(0xFF121A17) : const Color(0xFFF4EDE4),
            isDark ? 0.62 : 0.90,
          ) ??
          dominant;

      const lightInk = Color(0xFF0A1210);
      const darkInk = Color(0xFFF5F8F6);
      final onSurface = isDark ? darkInk : lightInk;

      var primary = _ensureReadableAccent(vibrant, onSurface, isDark);
      var secondary = _ensureReadableAccent(muted, onSurface, isDark);
      if (!isDark) {
        if (primary.computeLuminance() > 0.42) {
          primary = Color.lerp(primary, const Color(0xFF1A5C40), 0.72) ??
              const Color(0xFF1A5C40);
        }
        if (secondary.computeLuminance() > 0.50) {
          secondary = Color.lerp(secondary, const Color(0xFF8A4A35), 0.65) ??
              secondary;
        }
      }

      _blendScheme = ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: primary.computeLuminance() > 0.55 ? lightInk : Colors.white,
        secondary: secondary,
        onSecondary:
            secondary.computeLuminance() > 0.55 ? lightInk : Colors.white,
        surface: surface,
        onSurface: onSurface,
        error: const Color(0xFFB3261E),
        onError: Colors.white,
        outline: isDark
            ? const Color(0xFF8AA396)
            : const Color(0xFF3F5249),
        surfaceContainerHighest: Color.lerp(
              surface,
              primary,
              isDark ? 0.18 : 0.14,
            ) ??
            surface,
      );
    } catch (_) {
      _blendScheme = null;
    }
  }

  Color _ensureReadableAccent(Color accent, Color onSurface, bool isDark) {
    final contrast =
        (accent.computeLuminance() - onSurface.computeLuminance()).abs();
    final minContrast = isDark ? 0.22 : 0.34;
    if (contrast > minContrast) return accent;
    return Color.lerp(
          accent,
          isDark ? const Color(0xFF8DE7C0) : const Color(0xFF1A5C40),
          isDark ? 0.65 : 0.75,
        ) ??
        accent;
  }
}
