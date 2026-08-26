import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum VoiceOrbMood {
  idle,
  connecting,
  listening,
  hearing,
  speaking,
  error,
}

/// ChatGPT-style liquid circle that breathes, then flares with speech.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.mood,
    required this.level,
    this.onTap,
    this.size = 268,
  });

  final VoiceOrbMood mood;
  final double level;
  final VoidCallback? onTap;
  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  var _shown = 0.0;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _tick.addListener(_followLevel);
  }

  @override
  void dispose() {
    _tick.removeListener(_followLevel);
    _tick.dispose();
    super.dispose();
  }

  void _followLevel() {
    final target = widget.level.clamp(0.0, 1.0);
    final t = target > _shown ? 0.38 : 0.14;
    final next = _shown + (target - _shown) * t;
    if ((next - _shown).abs() > 0.002) {
      _shown = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final live = widget.mood == VoiceOrbMood.hearing ||
        widget.mood == VoiceOrbMood.speaking ||
        widget.mood == VoiceOrbMood.listening;
    return Semantics(
      button: widget.onTap != null,
      label: 'Voice tutor',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _tick,
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbPainter(
                  time: _tick.value * math.pi * 2,
                  energy: _shown,
                  mood: widget.mood,
                  primary: t.primaryAction,
                  secondary: t.secondaryAccent,
                  accent: t.decorationAccent,
                  muted: t.textMuted,
                  live: live,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.time,
    required this.energy,
    required this.mood,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.muted,
    required this.live,
  });

  final double time;
  final double energy;
  final VoiceOrbMood mood;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color muted;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.28;
    final breathe = 1 + 0.045 * math.sin(time * 1.15);
    final scale = switch (mood) {
      VoiceOrbMood.connecting => 0.86 + 0.06 * math.sin(time * 3.2),
      VoiceOrbMood.error || VoiceOrbMood.idle => 0.9,
      VoiceOrbMood.hearing => 1.04 + energy * 0.22,
      VoiceOrbMood.speaking => 1.08 + energy * 0.28,
      VoiceOrbMood.listening => 1.0,
    };
    final core = base * breathe * scale;
    final wobble = switch (mood) {
      VoiceOrbMood.speaking => 0.22 + energy * 0.55,
      VoiceOrbMood.hearing => 0.16 + energy * 0.42,
      VoiceOrbMood.connecting => 0.08,
      VoiceOrbMood.listening => 0.11,
      VoiceOrbMood.idle || VoiceOrbMood.error => 0.045,
    };

    if (mood == VoiceOrbMood.hearing) {
      _rings(canvas, center, core, primary);
    }

    final glow = Paint()
      ..color = (mood == VoiceOrbMood.error ? muted : primary)
          .withValues(alpha: 0.18 + energy * 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, core * (1.55 + energy * 0.35), glow);

    _blob(
      canvas,
      center,
      core * 1.08,
      time * 0.85,
      wobble,
      [
        secondary.withValues(alpha: 0.55),
        primary.withValues(alpha: 0.82),
        accent.withValues(alpha: 0.7),
      ],
      18,
    );
    _blob(
      canvas,
      center,
      core * 0.92,
      -time * 1.15 + 0.8,
      wobble * 0.85,
      [
        primary.withValues(alpha: 0.95),
        accent.withValues(alpha: 0.88),
        secondary.withValues(alpha: 0.75),
      ],
      10,
    );

    final shine = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: live ? 0.28 : 0.12),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: core));
    canvas.drawCircle(center, core * 0.62, shine);

    if (mood == VoiceOrbMood.connecting) {
      final sweep = Paint()
        ..color = primary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: core * 1.42),
        time * 3.4,
        math.pi * 0.7,
        false,
        sweep,
      );
    }
  }

  void _rings(Canvas canvas, Offset center, double core, Color color) {
    for (var i = 0; i < 3; i++) {
      final p = ((time * 0.35 + i / 3) % 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - p) * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(center, core * (1.25 + p * 1.1), paint);
    }
  }

  void _blob(
    Canvas canvas,
    Offset center,
    double radius,
    double phase,
    double wobble,
    List<Color> colors,
    double blur,
  ) {
    const n = 56;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final a = (i / n) * math.pi * 2;
      final deform = math.sin(a * 3 + phase * 1.4) * 0.55 +
          math.sin(a * 5 - phase * 1.9) * 0.28 +
          math.sin(a * 2 + phase * 0.7) * 0.22 +
          math.cos(a * 7 + phase * 2.4) * 0.12;
      final r = radius * (1 + wobble * deform);
      final p = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: const [0.15, 0.62, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) {
    return old.time != time ||
        old.energy != energy ||
        old.mood != mood ||
        old.primary != primary ||
        old.secondary != secondary;
  }
}
