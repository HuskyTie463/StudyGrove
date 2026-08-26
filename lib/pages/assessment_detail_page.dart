import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/readiness_engine.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';

class AssessmentDetailPage extends StatefulWidget {
  const AssessmentDetailPage({
    super.key,
    required this.panelOpacity,
    required this.assessment,
    required this.service,
  });

  final double panelOpacity;
  final Assessment assessment;
  final AssessmentService service;

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  late Assessment a;
  final _engine = const AssessmentReadinessEngine();
  final _notesCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _reflectionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    a = widget.assessment;
    _notesCtrl.text = a.notes ?? '';
    _weightCtrl.text = a.weightPercent?.toString() ?? '';
    _prepCtrl.text = a.estimatedPrepMinutes?.toString() ?? '';
    _reflectionCtrl.text = a.resultReflection ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _weightCtrl.dispose();
    _prepCtrl.dispose();
    _reflectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist(Assessment next) async {
    setState(() => a = next);
    await widget.service.updateAssessment(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final evidence = _engine.explain(a);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final body = ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        SgSectionHeader(
          eyebrow: a.course,
          title: a.title,
          subtitle: evidence.summary,
        ),
        SizedBox(height: t.gap(2)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SgStatusTag(label: a.type.label, color: t.secondaryAccent),
            SgStatusTag(
              label: evidence.state.calmLabel,
              color: switch (evidence.state) {
                ReadinessState.onTrack => t.pressureCalm,
                ReadinessState.needsAttention => t.pressureWatch,
                ReadinessState.timeIsTight => t.pressureTight,
                ReadinessState.missingInformation => t.pressureMissing,
              },
            ),
            SgStatusTag(label: a.dueLabel, color: t.textMuted),
          ],
        ),
        SizedBox(height: t.gap(2)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              Text(
                'Due ${MaterialLocalizations.of(context).formatFullDate(a.dueDate)} '
                '${TimeOfDay.fromDateTime(a.dueDate).format(context)}'
                '${a.timeZoneId != null ? ' · ${a.timeZoneId}' : ''}',
                style: TextStyle(color: t.textSecondary),
              ),
              SizedBox(height: t.gap(1)),
              ...evidence.factors.map(
                (f) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('· $f',
                      style: TextStyle(color: t.textMuted, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Prep tasks',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _addSubtask,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (a.subtasks.isEmpty)
                Text('No prep tasks yet.',
                    style: TextStyle(color: t.textMuted))
              else
                ...List.generate(a.subtasks.length, (i) {
                  final s = a.subtasks[i];
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.done,
                    title: Text(s.title),
                    onChanged: (_) async {
                      final next = !s.done;
                      final copy = [...a.subtasks];
                      copy[i] = AssessmentSubtask(title: s.title, done: next);
                      setState(() => a = a.copyWith(subtasks: copy));
                      await widget.service.toggleSubtask(a.id, i, next);
                    },
                  );
                }),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight, prep & confidence',
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight % (leave blank if unknown)',
                ),
              ),
              SizedBox(height: t.gap(1)),
              TextField(
                controller: _prepCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated prep minutes',
                ),
              ),
              SizedBox(height: t.gap(1.5)),
              Text('Confidence', style: TextStyle(color: t.textSecondary)),
              Slider(
                value: a.confidence ?? 0.5,
                onChanged: (v) => setState(
                  () => a = a.copyWith(confidence: v),
                ),
                onChangeEnd: (v) => _persist(a.copyWith(confidence: v)),
              ),
              Text(
                a.confidence == null
                    ? 'Not set — move slider to record'
                    : '${((a.confidence ?? 0) * 100).round()}%',
                style: TextStyle(color: t.textMuted, fontSize: 12),
              ),
              SizedBox(height: t.gap(1)),
              SgSecondaryButton(
                label: 'Save weight & prep',
                onPressed: () async {
                  final w = double.tryParse(_weightCtrl.text.trim());
                  final p = int.tryParse(_prepCtrl.text.trim());
                  await _persist(
                    a.copyWith(
                      weightPercent: w,
                      clearWeight: _weightCtrl.text.trim().isEmpty,
                      estimatedPrepMinutes: p,
                      clearPrep: _prepCtrl.text.trim().isEmpty,
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Lecture links, files, reminders…',
                ),
                onChanged: (v) => a = a.copyWith(notes: v),
              ),
              SizedBox(height: t.gap(1)),
              SgSecondaryButton(
                label: 'Save notes',
                onPressed: () => _persist(a.copyWith(notes: _notesCtrl.text)),
              ),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        if (a.linkedTopicIds.isNotEmpty)
          SgCard(
            child: Text(
              'Linked recall topics: ${a.linkedTopicIds.length}',
              style: TextStyle(color: t.textSecondary),
            ),
          ),
        SizedBox(height: t.gap(2)),
        if (a.completed || a.archived) ...[
          SgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Archive reflection',
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: t.gap(1)),
                Text(
                  'Optional — calm reflection if you entered a result. Not punitive.',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
                SizedBox(height: t.gap(1)),
                TextField(
                  controller: _reflectionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'What worked? What will you reuse?',
                  ),
                ),
                SizedBox(height: t.gap(1)),
                SgSecondaryButton(
                  label: 'Save reflection',
                  onPressed: () => _persist(
                    a.copyWith(resultReflection: _reflectionCtrl.text),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.gap(2)),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!a.completed)
              SgPrimaryButton(
                label: 'Mark complete',
                icon: Icons.check,
                onPressed: () async {
                  await widget.service.completeAssessment(a.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            SgSecondaryButton(
              label: 'Edit due date/time',
              icon: Icons.event,
              onPressed: _editDue,
            ),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete assessment?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await widget.service.deleteAssessment(a.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: t.destructive)),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(isWide ? 'Assessment detail' : a.title),
        backgroundColor: t.bgElevated,
      ),
      body: body,
    );
  }

  Future<void> _addSubtask() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add prep task'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == null || added.isEmpty) return;
    await widget.service.addSubtask(a.id, added);
    setState(() {
      a = a.copyWith(
        subtasks: [...a.subtasks, AssessmentSubtask(title: added)],
      );
    });
  }

  Future<void> _editDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: a.dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(a.dueDate),
    );
    if (tm == null || !mounted) return;
    await _persist(
      a.copyWith(
        dueDate: DateTime(d.year, d.month, d.day, tm.hour, tm.minute),
        timeZoneId: DateTime.now().timeZoneName,
      ),
    );
  }
}
