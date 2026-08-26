import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'style_family.dart';
import 'token_packs.dart';

/// Builds Material ThemeData from semantic DesignTokens.
class AppThemeBuilder {
  static ThemeData build({
    required VisualStyleFamily family,
    required bool dark,
    required SpacingDensity spacing,
    required ContrastLevel contrast,
    required bool reducedMotion,
  }) {
    final tokens = TokenPackRegistry.resolve(
      family: family,
      dark: dark,
      spacing: spacing,
      contrast: contrast,
      reducedMotion: reducedMotion,
    );

    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primaryAction,
      onPrimary: tokens.onPrimaryAction,
      secondary: tokens.secondaryAccent,
      onSecondary: tokens.onSecondaryAccent,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      error: tokens.destructive,
      onError: dark ? const Color(0xFF1A0A0A) : Colors.white,
      outline: tokens.border,
      surfaceContainerHighest: tokens.surfaceElevated,
    );

    TextStyle face(TextStyle base) => GoogleFonts.manrope(
          textStyle: base.copyWith(
            color: tokens.textPrimary,
            height: base.height ?? 1.35,
          ),
        );

    final textTheme = TextTheme(
      displayLarge: face(const TextStyle(fontSize: 48, fontWeight: FontWeight.w600)),
      displayMedium: face(const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
      displaySmall: face(const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      headlineLarge: face(const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      headlineMedium: face(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      headlineSmall: face(const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      titleLarge: face(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      titleMedium: face(const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      titleSmall: face(const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      bodyLarge: face(const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      bodyMedium: face(const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      bodySmall: face(const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      labelLarge: face(const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      labelMedium: face(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      labelSmall: face(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );

    final isBrutal = family == VisualStyleFamily.neoBrutal;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.manrope().fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [tokens],
      iconTheme: IconThemeData(color: tokens.textPrimary),
      primaryIconTheme: IconThemeData(color: tokens.textPrimary),
      dividerColor: tokens.divider,
      listTileTheme: ListTileThemeData(
        iconColor: tokens.textPrimary,
        textColor: tokens.textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          side: isBrutal
              ? BorderSide(color: tokens.border, width: 2)
              : BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: tokens.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          side: BorderSide(
            color: tokens.border.withValues(alpha: isBrutal ? 1 : 0.28),
            width: isBrutal ? 2 : 0.8,
          ),
        ),
        shadowColor: tokens.shadowColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primaryAction,
          foregroundColor: tokens.onPrimaryAction,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              isBrutal ? tokens.radiusSm : tokens.radiusMd,
            ),
            side: isBrutal
                ? BorderSide(color: tokens.border, width: 2)
                : BorderSide.none,
          ),
          textStyle: face(const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(44, 44),
          side: BorderSide(
            color: tokens.border,
            width: isBrutal ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              isBrutal ? tokens.radiusSm : tokens.radiusMd,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.bgMuted.withValues(alpha: dark ? 0.5 : 0.65),
        labelStyle: TextStyle(color: tokens.textSecondary),
        hintStyle: TextStyle(color: tokens.textMuted),
        floatingLabelStyle: TextStyle(color: tokens.primaryAction),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: tokens.focusRing, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.bgElevated,
        selectedIconTheme: IconThemeData(color: tokens.primaryAction),
        unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: tokens.primaryAction,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: tokens.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.bgElevated,
        selectedItemColor: tokens.primaryAction,
        unselectedItemColor: tokens.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.primaryAction,
        thumbColor: tokens.primaryAction,
        inactiveTrackColor: tokens.primaryAction.withValues(alpha: 0.28),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.bgMuted,
        selectedColor: tokens.primaryAction.withValues(alpha: 0.35),
        labelStyle: TextStyle(color: tokens.textPrimary),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.bgMuted,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
      ),
      pageTransitionsTheme: reducedMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(),
    );
  }
}
