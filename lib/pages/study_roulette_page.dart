import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/study_roulette_engine.dart';
import '../services/study_roulette_store.dart';
import '../ui/shared_ui.dart';

class StudyRoulettePage extends StatefulWidget {
  const StudyRoulettePage({super.key, required this.panelOpacity});

  final double panelOpacity;

  @override
  State<StudyRoulettePage> createState() => _StudyRoulettePageState();
}

class _StudyRoulettePageState extends State<StudyRoulettePage> with TickerProviderStateMixin {
  final _store = StudyRouletteStore();
  late final math.Random _rng;
  late StudyRouletteEngine _engine;
  late AnimationController _wheelController;
  Animation<double> _angleAnim = const AlwaysStoppedAnimation(0);

  double _endRotation = 0;
  int _progress = 0;
  List<String> _rewards = [];
  RouletteDraw? _current;
  bool _spinning = false;
  bool _canSwap = false;

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    // Separate RNG so wheel/decoration rolls don’t share state with challenge draws.
    _engine = StudyRouletteEngine(math.Random());
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _angleAnim = Tween<double>(begin: 0, end: 0).animate(_wheelController);
    _refreshMeta();
  }

  Future<void> _refreshMeta() async {
    final p = await _store.progressTowardReward();
    final r = await _store.loadRewards();
    if (mounted) {
      setState(() {
        _progress = p;
        _rewards = r;
      });
    }
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    final draw = _engine.spin();
    final spins = 5 + _rng.nextInt(4);
    final delta = _engine.rotationDelta(draw.sliceIndex, spins);
    final start = _endRotation;
    final end = start + delta;

    _angleAnim = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
    );

    setState(() {
      _spinning = true;
      _canSwap = true;
      _current = null;
    });

    _wheelController.duration = Duration(milliseconds: 2800 + _rng.nextInt(800));
    await _wheelController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _endRotation = end;
      _current = draw;
      _spinning = false;
    });
  }

  void _swapOnce() {
    if (!_canSwap || _spinning || _current == null) return;
    final draw = _engine.spin();
    setState(() {
      _current = draw;
      _canSwap = false;
    });
  }

  Future<void> _logComplete() async {
    if (_current == null || _spinning) return;
    final unlocked = await _store.completeChallenge();
    final p = await _store.progressTowardReward();
    final rewards = await _store.loadRewards();
    if (!mounted) return;
    setState(() {
      _current = null;
      _canSwap = false;
      _progress = p;
      _rewards = rewards;
    });

    if (unlocked) {
      final pool = rewards.isEmpty ? StudyRouletteStore.defaultRewards : rewards;
      final reward = pool[math.Random().nextInt(pool.length)];
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Mystery reward unlocked'),
          content: Text('You earned: $reward'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Lovely')),
          ],
        ),
      );
    } else {
      if (!context.mounted) return;
      final doneMsg = switch (p) {
        1 => 'Progress 1/3 — two more completed challenges until a mystery reward.',
        2 => 'Progress 2/3 — one more completed challenge until a mystery reward.',
        _ => 'Progress $p/3 — keep going.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(doneMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _rarityLabel(ChallengeRarity r) => switch (r) {
        ChallengeRarity.common => 'Common',
        ChallengeRarity.rare => 'Rare',
        ChallengeRarity.epic => 'Epic',
      };

  Widget _challengeCard() {
    final scheme = Theme.of(context).colorScheme;
    final c = _current;
    if (c == null) {
      return FrostPanel(
        opacity: widget.panelOpacity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _spinning ? 'Spinning…' : 'Spin the wheel to pull a challenge.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.90)),
          ),
        ),
      );
    }

    return FrostPanel(
      opacity: widget.panelOpacity,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GreenChip(c.primaryLabel),
                    GreenChip(_rarityLabel(c.rarity)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(c.body, style: TextStyle(height: 1.35, color: scheme.onSurface.withValues(alpha: 0.88))),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.amber.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.fortuneLine, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.88))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SoftButton(
                  label: 'Done — log it',
                  icon: Icons.check_circle_outline,
                  filled: true,
                  onPressed: _spinning ? null : _logComplete,
                ),
                SoftButton(
                  label: _canSwap ? 'Swap once' : 'Swap used',
                  icon: Icons.shuffle,
                  onPressed: (_canSwap && !_spinning) ? _swapOnce : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRewards() async {
    final controller = TextEditingController(text: _rewards.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mystery rewards'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'One reward per line (e.g. walk, episode, treat…)',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final lines = controller.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await _store.saveRewards(lines);
      await _refreshMeta();
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Study Roulette',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _editRewards,
                  icon: const Icon(Icons.card_giftcard, size: 18),
                  label: const Text('Rewards'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GreenChip('Mystery: ${_progress}/3 logged'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Spin picks the challenge. After you actually do it, tap Done — log it three times total to unlock a random reward from your list (Rewards button).',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.88)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: SizedBox(
                        height: 280,
                        width: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _wheelController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _angleAnim.value,
                                  child: child,
                                );
                              },
                              child: CustomPaint(
                                size: const Size(260, 260),
                                painter: _FortuneWheelPainter(labels: RouletteDraw.wheelLabels),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              child: Icon(
                                Icons.arrow_drop_down,
                                size: 36,
                                color: scheme.onSurface.withValues(alpha: 0.90),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SoftButton(
                      label: _spinning ? 'Spinning…' : 'Spin the wheel',
                      icon: Icons.casino,
                      filled: true,
                      onPressed: _spinning ? null : _spin,
                    ),
                    const SizedBox(height: 16),
                    _challengeCard(),
                    const SizedBox(height: 14),
                    FrostPanel(
                      opacity: widget.panelOpacity,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('What you get', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                              'Wild = pick what you’re avoiding. Combo = study block + movement. Move = mostly movement. '
                              'Other slices are study modes (cards, quiz, notes…). Many study rolls also add a short movement finisher—stop if anything hurts.',
                              style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.88)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FortuneWheelPainter extends CustomPainter {
  _FortuneWheelPainter({required this.labels});

  final List<String> labels;

  static const _sliceColors = [
    Color(0xFF1C6E52),
    Color(0xFF156B54),
    Color(0xFF0F7A5A),
    Color(0xFF1B5E4C),
    Color(0xFF238763),
    Color(0xFF2AD08F),
    Color(0xFF427A6B),
    Color(0xFF145544),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final n = labels.length;
    final sweep = 2 * math.pi / n;

    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _sliceColors[i % _sliceColors.length];
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(rect, start, sweep, true, paint);

      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.14);
      canvas.drawArc(rect, start, sweep, true, border);
    }

    final hole = Paint()..color = const Color(0xFF060B0A);
    canvas.drawCircle(c, r * 0.18, hole);

    for (var i = 0; i < n; i++) {
      final ang = -math.pi / 2 + i * sweep + sweep / 2;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ang);
      canvas.translate(r * 0.62, 0);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.5);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FortuneWheelPainter oldDelegate) => oldDelegate.labels != labels;
}
