import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/design_tokens.dart';
import 'math_text.dart';

class SgCard extends StatelessWidget {
  const SgCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isBrutal = t.styleId == 'neoBrutal';
    final content = Container(
      padding: padding ?? EdgeInsets.all(t.gap(2)),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(
          color: accent ??
              t.border.withValues(alpha: isBrutal ? 1 : 0.28),
          width: isBrutal ? 2 : 0.8,
        ),
        boxShadow: t.cardElevation <= 0
            ? (isBrutal
                ? [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: const Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: t.shadowColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ])
            : [
                BoxShadow(
                  color: t.shadowColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );

    Widget result = content;
    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(t.radiusLg),
          child: content,
        ),
      );
    }
    if (semanticLabel != null) {
      result = Semantics(label: semanticLabel, button: onTap != null, child: result);
    }
    return result;
  }
}

class SgPrimaryButton extends StatelessWidget {
  const SgPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
    final btn = FilledButton(onPressed: onPressed, child: child);
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SgSecondaryButton extends StatelessWidget {
  const SgSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class SgStatusTag extends StatelessWidget {
  const SgStatusTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.gap(1.25),
          vertical: t.gap(0.75),
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(t.radiusXl),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              SizedBox(width: t.gap(0.5)),
            ],
            // Colour is not the only cue — text label always present.
            Text(
              label,
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SgSectionHeader extends StatelessWidget {
  const SgSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: t.textMuted,
          ),
        ),
        SizedBox(height: t.gap(1)),
        MathText(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: t.textPrimary,
              ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: t.gap(1)),
          MathText(
            subtitle!,
            style: TextStyle(
              color: t.textMuted,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

class SgEmptyState extends StatelessWidget {
  const SgEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.spa_outlined,
                size: 40,
                color: t.decorationAccent.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: t.gap(2)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: t.gap(1)),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, height: 1.5),
            ),
            if (action != null) ...[
              SizedBox(height: t.gap(2.5)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SgSegmented<T extends Object> extends StatelessWidget {
  const SgSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

void announceForAccessibility(BuildContext context, String message) {
  SemanticsService.announce(message, TextDirection.ltr);
}
