import 'package:flutter/material.dart';

class AppThemes {
  static TextTheme _textThemeFor(Color onSurface, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;
    return base.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );
  }

  static ThemeData get light {
    // Darker sage so icons/labels stay readable on cream surfaces.
    const primary = Color(0xFF1F6B4A);
    const secondary = Color(0xFFA85A42);
    const surface = Color(0xFFF7F1EA);
    const scaffold = Color(0xFFF3EBE3);
    const onSurface = Color(0xFF0E1613);

    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: const Color(0xFFE8DDD0),
      outline: const Color(0xFF3F5249),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: _textThemeFor(onSurface, Brightness.light),
      primaryTextTheme: _textThemeFor(onSurface, Brightness.light),
      iconTheme: const IconThemeData(color: onSurface),
      primaryIconTheme: const IconThemeData(color: onSurface),
      listTileTheme: const ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurface),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: onSurface),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.88)),
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.62)),
        floatingLabelStyle: const TextStyle(color: primary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return onSurface;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return onSurface;
          }),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFFEFE6DC),
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: onSurface),
        selectedLabelTextStyle:
            const TextStyle(color: primary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(
          color: onSurface.withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurface,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: onSurface),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        showUnselectedLabels: true,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.28),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static ThemeData get dark {
    const primary = Color(0xFF2AD08F);
    const secondary = Color(0xFF29C37F);
    const surface = Color(0xFF0B1411);
    const scaffold = Color(0xFF060B0A);
    const onSurface = Color(0xFFF5F8F6);

    final scheme = const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: Color(0xFF123B2E),
      outline: Color(0xFF8AA396),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: _textThemeFor(onSurface, Brightness.dark),
      primaryTextTheme: _textThemeFor(onSurface, Brightness.dark),
      iconTheme: const IconThemeData(color: onSurface),
      listTileTheme: const ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF050907),
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme:
            IconThemeData(color: onSurface.withValues(alpha: 0.90)),
        selectedLabelTextStyle:
            const TextStyle(color: primary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle:
            TextStyle(color: onSurface.withValues(alpha: 0.82)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF050907),
        selectedItemColor: primary,
        unselectedItemColor: onSurface.withValues(alpha: 0.82),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.25),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1C6E52),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static ThemeData blendFrom(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0A1210) : const Color(0xFFF0E9E0),
      textTheme: _textThemeFor(onSurface, scheme.brightness),
      primaryTextTheme: _textThemeFor(onSurface, scheme.brightness),
      iconTheme: IconThemeData(color: onSurface),
      primaryIconTheme: IconThemeData(color: onSurface),
      listTileTheme:
          ListTileThemeData(iconColor: onSurface, textColor: onSurface),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurface),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: onSurface),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(
          color: onSurface.withValues(alpha: isDark ? 0.8 : 0.88),
        ),
        hintStyle: TextStyle(
          color: onSurface.withValues(alpha: isDark ? 0.55 : 0.62),
        ),
        floatingLabelStyle: TextStyle(color: primary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return onSurface;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return onSurface;
          }),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.98),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.90 : 0.96),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(
          color: onSurface.withValues(alpha: isDark ? 0.78 : 0.92),
        ),
        selectedLabelTextStyle:
            TextStyle(color: primary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(
          color: onSurface.withValues(alpha: isDark ? 0.82 : 0.90),
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.97),
        selectedItemColor: primary,
        unselectedItemColor: onSurface.withValues(alpha: isDark ? 0.82 : 0.92),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: onSurface),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.28),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
    );
  }
}
