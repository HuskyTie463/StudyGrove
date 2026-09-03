import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/style_family.dart';

/// Per-style chrome: rail overlay + small marks used on assessments.
class StyleRailMotif extends StatelessWidget {
  const StyleRailMotif({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final family = themeController.style;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RailMotifPainter(
                family: family,
                color: context.tokens.decorationAccent,
                ink: context.tokens.textMuted,
                secondary: context.tokens.secondaryAccent,
                dark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class StyleAssessmentMark extends StatelessWidget {
  const StyleAssessmentMark({
    super.key,
    this.size = 22,
    this.color,
    this.progress,
  });

  final double size;
  final Color? color;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final family = themeController.style;
    final t = context.tokens;
    final c = color ?? t.decorationAccent;
    return Icon(
      assessmentIconFor(family, progress),
      size: size,
      color: c,
    );
  }
}

IconData assessmentIconFor(VisualStyleFamily family, [double? progress]) {
  final p = progress ?? 0.4;
  return switch (family) {
    VisualStyleFamily.naturalistic => p >= 0.995
        ? Icons.park_rounded
        : p >= 0.85
            ? Icons.yard_outlined
            : p >= 0.60
                ? Icons.local_florist_outlined
                : p >= 0.30
                    ? Icons.eco_outlined
                    : Icons.spa_outlined,
    VisualStyleFamily.signature => Icons.auto_stories_outlined,
    VisualStyleFamily.softCute => p >= 0.85
        ? Icons.favorite_rounded
        : p >= 0.45
            ? Icons.filter_vintage_outlined
            : Icons.favorite_border_rounded,
    VisualStyleFamily.neoBrutal => Icons.grid_view_rounded,
    VisualStyleFamily.aurora => Icons.blur_circular_outlined,
    VisualStyleFamily.quietFocus => Icons.horizontal_rule_rounded,
    VisualStyleFamily.dusk => Icons.nights_stay_outlined,
    VisualStyleFamily.harbor => Icons.water_outlined,
  };
}

class _RailMotifPainter extends CustomPainter {
  _RailMotifPainter({
    required this.family,
    required this.color,
    required this.ink,
    required this.secondary,
    required this.dark,
  });

  final VisualStyleFamily family;
  final Color color;
  final Color ink;
  final Color secondary;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    switch (family) {
      case VisualStyleFamily.naturalistic:
        _vine(canvas, size);
      case VisualStyleFamily.signature:
        _botanicalMarks(canvas, size);
      case VisualStyleFamily.softCute:
        _stones(canvas, size);
      case VisualStyleFamily.neoBrutal:
        _blocks(canvas, size);
      case VisualStyleFamily.aurora:
        _glowRail(canvas, size);
      case VisualStyleFamily.quietFocus:
        _inkLine(canvas, size);
      case VisualStyleFamily.dusk:
        _glowRail(canvas, size);
      case VisualStyleFamily.harbor:
        _harborWave(canvas, size);
    }
  }

  void _vine(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final x0 = 10.0;
    path.moveTo(x0, 8);
    for (var y = 8.0; y < size.height - 8; y += 18) {
      final sway = math.sin(y / 42) * 7;
      path.lineTo(x0 + sway, y);
    }
    canvas.drawPath(path, stem);
    final leaf = Paint()..color = color.withValues(alpha: 0.45);
    for (var y = 28.0; y < size.height - 20; y += 36) {
      final sway = math.sin(y / 42) * 7;
      _drawLeaf(canvas, Offset(x0 + sway + 6, y), leaf, flip: y % 72 < 36);
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, Paint paint, {required bool flip}) {
    final path = Path();
    final dir = flip ? -1.0 : 1.0;
    path.moveTo(origin.dx, origin.dy);
    path.quadraticBezierTo(
      origin.dx + 10 * dir,
      origin.dy - 6,
      origin.dx + 16 * dir,
      origin.dy,
    );
    path.quadraticBezierTo(
      origin.dx + 10 * dir,
      origin.dy + 6,
      origin.dx,
      origin.dy,
    );
    canvas.drawPath(path, paint);
  }

  void _botanicalMarks(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.4);
    for (var y = 24.0; y < size.height - 16; y += 48) {
      _drawLeaf(canvas, Offset(14, y), paint, flip: false);
      canvas.drawCircle(Offset(8, y + 16), 2.2, paint);
    }
  }

  void _stones(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    for (var y = 20.0; y < size.height - 16; y += 28) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(12, y), width: 14, height: 10),
          const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  void _blocks(Canvas canvas, Size size) {
    final a = Paint()..color = color;
    final b = Paint()..color = secondary;
    for (var i = 0; i < 6; i++) {
      final y = 18.0 + i * 52;
      canvas.drawRect(Rect.fromLTWH(4, y, 10, 10), i.isEven ? a : b);
      canvas.drawRect(Rect.fromLTWH(10, y + 14, 8, 8), i.isEven ? b : a);
    }
  }

  void _glowRail(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, 8, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.45),
          secondary.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );
  }

  void _inkLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(6, 12), Offset(6, size.height - 12), paint);
  }

  void _harborWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(8, 12);
    for (var y = 12.0; y < size.height - 8; y += 16) {
      final x = 8 + math.sin(y / 22) * 5;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RailMotifPainter oldDelegate) {
    return oldDelegate.family != family ||
        oldDelegate.color != color ||
        oldDelegate.dark != dark;
  }
}
