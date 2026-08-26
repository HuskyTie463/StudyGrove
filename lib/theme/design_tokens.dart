import 'package:flutter/material.dart';

/// Semantic design tokens consumed by UI primitives (never hard-code theme colours in widgets).
@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  const DesignTokens({
    required this.bg,
    required this.bgElevated,
    required this.bgMuted,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.secondaryAccent,
    required this.onSecondaryAccent,
    required this.positive,
    required this.warning,
    required this.urgent,
    required this.destructive,
    required this.focusRing,
    required this.shadowColor,
    required this.decorationAccent,
    required this.pressureCalm,
    required this.pressureWatch,
    required this.pressureTight,
    required this.pressureMissing,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.spaceUnit,
    required this.cardElevation,
    required this.motionScale,
    required this.editorialDisplay,
    required this.bodyFamily,
    required this.styleId,
  });

  final Color bg;
  final Color bgElevated;
  final Color bgMuted;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color primaryAction;
  final Color onPrimaryAction;
  final Color secondaryAccent;
  final Color onSecondaryAccent;
  final Color positive;
  final Color warning;
  final Color urgent;
  final Color destructive;
  final Color focusRing;
  final Color shadowColor;
  final Color decorationAccent;
  final Color pressureCalm;
  final Color pressureWatch;
  final Color pressureTight;
  final Color pressureMissing;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double spaceUnit;
  final double cardElevation;
  final double motionScale;
  final String editorialDisplay;
  final String bodyFamily;
  final String styleId;

  EdgeInsets pagePadding(bool compact) => EdgeInsets.symmetric(
        horizontal: spaceUnit * (compact ? 2.0 : 3.5),
        vertical: spaceUnit * (compact ? 2.0 : 2.5),
      );

  double gap(double units) => spaceUnit * units;

  @override
  DesignTokens copyWith({
    Color? bg,
    Color? bgElevated,
    Color? bgMuted,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? secondaryAccent,
    Color? onSecondaryAccent,
    Color? positive,
    Color? warning,
    Color? urgent,
    Color? destructive,
    Color? focusRing,
    Color? shadowColor,
    Color? decorationAccent,
    Color? pressureCalm,
    Color? pressureWatch,
    Color? pressureTight,
    Color? pressureMissing,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? spaceUnit,
    double? cardElevation,
    double? motionScale,
    String? editorialDisplay,
    String? bodyFamily,
    String? styleId,
  }) {
    return DesignTokens(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      bgMuted: bgMuted ?? this.bgMuted,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primaryAction: primaryAction ?? this.primaryAction,
      onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      onSecondaryAccent: onSecondaryAccent ?? this.onSecondaryAccent,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      urgent: urgent ?? this.urgent,
      destructive: destructive ?? this.destructive,
      focusRing: focusRing ?? this.focusRing,
      shadowColor: shadowColor ?? this.shadowColor,
      decorationAccent: decorationAccent ?? this.decorationAccent,
      pressureCalm: pressureCalm ?? this.pressureCalm,
      pressureWatch: pressureWatch ?? this.pressureWatch,
      pressureTight: pressureTight ?? this.pressureTight,
      pressureMissing: pressureMissing ?? this.pressureMissing,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      spaceUnit: spaceUnit ?? this.spaceUnit,
      cardElevation: cardElevation ?? this.cardElevation,
      motionScale: motionScale ?? this.motionScale,
      editorialDisplay: editorialDisplay ?? this.editorialDisplay,
      bodyFamily: bodyFamily ?? this.bodyFamily,
      styleId: styleId ?? this.styleId,
    );
  }

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    double d(double a, double b) => a + (b - a) * t;
    return DesignTokens(
      bg: l(bg, other.bg),
      bgElevated: l(bgElevated, other.bgElevated),
      bgMuted: l(bgMuted, other.bgMuted),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      divider: l(divider, other.divider),
      primaryAction: l(primaryAction, other.primaryAction),
      onPrimaryAction: l(onPrimaryAction, other.onPrimaryAction),
      secondaryAccent: l(secondaryAccent, other.secondaryAccent),
      onSecondaryAccent: l(onSecondaryAccent, other.onSecondaryAccent),
      positive: l(positive, other.positive),
      warning: l(warning, other.warning),
      urgent: l(urgent, other.urgent),
      destructive: l(destructive, other.destructive),
      focusRing: l(focusRing, other.focusRing),
      shadowColor: l(shadowColor, other.shadowColor),
      decorationAccent: l(decorationAccent, other.decorationAccent),
      pressureCalm: l(pressureCalm, other.pressureCalm),
      pressureWatch: l(pressureWatch, other.pressureWatch),
      pressureTight: l(pressureTight, other.pressureTight),
      pressureMissing: l(pressureMissing, other.pressureMissing),
      radiusSm: d(radiusSm, other.radiusSm),
      radiusMd: d(radiusMd, other.radiusMd),
      radiusLg: d(radiusLg, other.radiusLg),
      radiusXl: d(radiusXl, other.radiusXl),
      spaceUnit: d(spaceUnit, other.spaceUnit),
      cardElevation: d(cardElevation, other.cardElevation),
      motionScale: d(motionScale, other.motionScale),
      editorialDisplay: t < 0.5 ? editorialDisplay : other.editorialDisplay,
      bodyFamily: t < 0.5 ? bodyFamily : other.bodyFamily,
      styleId: t < 0.5 ? styleId : other.styleId,
    );
  }

  static DesignTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>();
    assert(tokens != null, 'DesignTokens missing from ThemeData.extensions');
    return tokens!;
  }

  /// Required semantic keys for tests / pack registration.
  static const requiredKeys = <String>[
    'bg',
    'bgElevated',
    'surface',
    'textPrimary',
    'textMuted',
    'border',
    'primaryAction',
    'secondaryAccent',
    'positive',
    'warning',
    'urgent',
    'destructive',
    'focusRing',
    'pressureCalm',
    'pressureWatch',
    'pressureTight',
    'pressureMissing',
  ];
}

extension DesignTokensX on BuildContext {
  DesignTokens get tokens => DesignTokens.of(this);
}
