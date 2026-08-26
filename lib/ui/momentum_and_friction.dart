import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/friction_and_progress.dart';
import '../theme/design_tokens.dart';
import 'sg_primitives.dart';

/// Short initiation bridge: energy → physical transition → honest answer → continue.
class MomentumBridgeSheet extends StatefulWidget {
  const MomentumBridgeSheet({
    super.key,
    required this.sessionTitle,
    required this.durationMinutes,
    required this.onContinue,
    this.frictionService,
  });

  final String sessionTitle;
  final int durationMinutes;
  final VoidCallback onContinue;
  final FrictionService? frictionService;

  static Future<void> open(
    BuildContext context, {
    required String sessionTitle,
    required int durationMinutes,
    required VoidCallback onContinue,
    FrictionService? frictionService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MomentumBridgeSheet(
        sessionTitle: sessionTitle,
        durationMinutes: durationMinutes,
        onContinue: onContinue,
        frictionService: frictionService,
      ),
    );
  }

  @override
  State<MomentumBridgeSheet> createState() => _MomentumBridgeSheetState();
}

class _MomentumBridgeSheetState extends State<MomentumBridgeSheet> {
  int _step = 0;
  StudyContextMode _mode = StudyContextMode.balanced;
  final _answerCtrl = TextEditingController();

  static const _transitions = [
    'Stand up and roll your shoulders once.',
    'Clear just the centre of your desk.',
    'Fill a glass of water and set it beside you.',
    'Put your phone face-down out of reach.',
  ];

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.gap(2.5),
        t.gap(1),
        t.gap(2.5),
        MediaQuery.viewInsetsOf(context).bottom + t.gap(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SgSectionHeader(
            eyebrow: 'Momentum bridge',
            title: widget.sessionTitle,
            subtitle:
                '${widget.durationMinutes} min · a short start, not a performance',
          ),
          SizedBox(height: t.gap(2.5)),
          if (_step == 0) ...[
            Text('How’s your energy / context?', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: t.gap(1.5)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StudyContextMode.values.map((m) {
                final selected = _mode == m;
                return ChoiceChip(
                  label: Text(m.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _mode = m),
                );
              }).toList(),
            ),
            SizedBox(height: t.gap(2)),
            SgPrimaryButton(
              label: 'Next',
              expanded: true,
              onPressed: () => setState(() => _step = 1),
            ),
          ] else if (_step == 1) ...[
            Text('One physical transition', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: t.gap(1)),
            SgCard(
              child: Text(
                _transitions[DateTime.now().minute % _transitions.length],
                style: TextStyle(color: t.textSecondary, height: 1.45),
              ),
            ),
            SizedBox(height: t.gap(2)),
            SgPrimaryButton(
              label: 'Done — next',
              expanded: true,
              onPressed: () => setState(() => _step = 2),
            ),
          ] else if (_step == 2) ...[
            Text('One honest answer', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: t.gap(1)),
            Text(
              'What’s the smallest true next step for this session?',
              style: TextStyle(color: t.textMuted),
            ),
            SizedBox(height: t.gap(1.5)),
            TextField(
              controller: _answerCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. open past paper Q1 and write one outline',
              ),
            ),
            SizedBox(height: t.gap(2)),
            SgPrimaryButton(
              label: 'Continue into session',
              expanded: true,
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                announceForAccessibility(
                  context,
                  'Starting ${widget.durationMinutes} minute session: ${widget.sessionTitle}',
                );
                Navigator.pop(context);
                widget.onContinue();
              },
            ),
            SizedBox(height: t.gap(1)),
            Text(
              'Not medical advice — just a gentle start cue.',
              style: TextStyle(color: t.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class FrictionChips extends StatelessWidget {
  const FrictionChips({super.key, required this.onSelected});

  final ValueChanged<FrictionReason> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FrictionReason.values.map((r) {
        return ActionChip(
          label: Text(r.label),
          onPressed: () => onSelected(r),
          side: BorderSide(color: t.border),
        );
      }).toList(),
    );
  }
}
