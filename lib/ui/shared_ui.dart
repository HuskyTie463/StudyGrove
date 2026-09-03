// lib/ui/shared_ui.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class FrostPanel extends StatelessWidget {
  const FrostPanel({
    super.key,
    required this.child,
    this.opacity = 0.55,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double opacity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dense = Theme.of(context).brightness == Brightness.light;
    // Map slider 0.20–0.85 across a wide visible alpha range.
    final t = ((opacity.clamp(0.20, 0.85) - 0.20) / 0.65).clamp(0.0, 1.0);
    final panelAlpha = dense
        ? (0.22 + t * 0.73) // 0.22 (very clear) → 0.95 (solid)
        : (0.12 + t * 0.78); // 0.12 → 0.90

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: panelAlpha),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outline.withValues(alpha: dense ? 0.22 : 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: dense ? 0.06 : 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: scheme.onSurface),
            child: IconTheme.merge(
              data: IconThemeData(color: scheme.onSurface),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent chrome so wallpaper shows through rails and bars.
class FrostChrome extends StatelessWidget {
  const FrostChrome({
    super.key,
    required this.child,
    this.alpha,
  });

  final Widget child;
  final double? alpha;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    // Translucent wash only — BackdropFilter re-samples the wallpaper and
    // composites a second, often misaligned copy under rails and bars.
    final a = alpha ?? (light ? 0.58 : 0.48);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: a),
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withValues(alpha: light ? 0.14 : 0.10),
          ),
        ),
      ),
      child: child,
    );
  }
}

class GreenChip extends StatelessWidget {
  const GreenChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }
}

class QuickRow extends StatelessWidget {
  const QuickRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.90),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: onSurface),
        ),
      ],
    );
  }
}

class TimeStepperTile extends StatelessWidget {
  const TimeStepperTile({
    super.key,
    this.title,
    this.label,
    required this.minutes,
    required this.onMinus,
    required this.onPlus,
  });

  final String? title;
  final String? label;
  final int minutes;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final text = title ?? label ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          GreenChip("$minutes min"),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}
