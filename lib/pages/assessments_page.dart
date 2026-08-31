import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/readiness_engine.dart';
import '../services/subject_service.dart';
import '../theme/design_tokens.dart';
import '../theme/style_family.dart';
import '../main.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';
import '../ui/shell_scope.dart';
import '../ui/style_motifs.dart';

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage({
    super.key,
    required this.panelOpacity,
    required this.onOpacityChanged,
    required this.assessmentService,
    required this.onOpenAssessment,
    this.subjectService,
    this.onContinuePreparation,
    this.focusSubjectId,
  });

  final double panelOpacity;
  final ValueChanged<double> onOpacityChanged;
  final AssessmentService assessmentService;
  final SubjectService? subjectService;
  final void Function(Assessment assessment) onOpenAssessment;
  final void Function(Assessment assessment)? onContinuePreparation;
  final String? focusSubjectId;

  @override
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  late final Stream<List<Assessment>> _assessmentsStream;
  final _engine = const AssessmentReadinessEngine();

  @override
  void initState() {
    super.initState();
    _assessmentsStream = widget.assessmentService.streamAssessments();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPhone = MediaQuery.sizeOf(context).width < 700;
    final useGarden =
        themeController.style.usesPlantPhases;

    return DecoratedBox(
      decoration: useGarden
          ? const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/studio_garden/background_greenhouse.png',
                ),
                fit: BoxFit.cover,
              ),
            )
          : BoxDecoration(color: t.bg),
      child: ColoredBox(
        color: useGarden ? t.bg.withValues(alpha: 0.72) : t.bg,
        child: SafeArea(
          child: StreamBuilder<List<Assessment>>(
            stream: _assessmentsStream,
            builder: (context, assessmentSnap) {
              if (assessmentSnap.connectionState == ConnectionState.waiting &&
                  !assessmentSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (assessmentSnap.hasError) {
                return SgEmptyState(
                  title: 'Couldn’t load assessments',
                  body: '${assessmentSnap.error}',
                );
              }
              final assessments =
                  assessmentSnap.data ?? const <Assessment>[];

              final subjectsStream = widget.subjectService?.streamSubjects();
              if (subjectsStream == null) {
                return _body(
                  context,
                  assessments: assessments,
                  subjects: const [],
                  isPhone: isPhone,
                );
              }
              return StreamBuilder<List<Subject>>(
                stream: subjectsStream,
                builder: (context, subjectSnap) {
                  return _body(
                    context,
                    assessments: assessments,
                    subjects: subjectSnap.data ?? const [],
                    isPhone: isPhone,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required List<Assessment> assessments,
    required List<Subject> subjects,
    required bool isPhone,
  }) {
    final t = context.tokens;
    final scoped = [...assessments.where(
      (a) => matchesSelectedSubject(
        selectedId: widget.focusSubjectId,
        subjects: subjects,
        itemSubjectId: a.subjectId,
        course: a.course,
        title: a.title,
      ),
    )]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final subjectById = {for (final s in subjects) s.id: s};

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 48,
            isPhone ? 20 : 32,
            isPhone ? 16 : 48,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Assessments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SgPrimaryButton(
                  label: 'Create',
                  icon: Icons.add,
                  onPressed: () => _quickCreate(context, subjects),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: t.gap(2))),
        if (scoped.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: SgEmptyState(
              title: 'No assessments',
              body: 'Create one with a due date.',
              action: SgPrimaryButton(
                label: 'Create',
                icon: Icons.add,
                onPressed: () => _quickCreate(context, subjects),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isPhone ? 16 : 48,
              0,
              isPhone ? 16 : 48,
              48,
            ),
            sliver: SliverList.separated(
              itemCount: scoped.length,
              separatorBuilder: (_, _) => SizedBox(height: t.gap(1.5)),
              itemBuilder: (context, i) {
                final a = scoped[i];
                return _AssessmentDecisionCard(
                  assessment: a,
                  evidence: _engine.explain(a),
                  subject:
                      a.subjectId == null ? null : subjectById[a.subjectId!],
                  nextAction: _engine.bestNextAction(a, _engine.explain(a)),
                  onOpen: () => widget.onOpenAssessment(a),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _quickCreate(
    BuildContext context,
    List<Subject> subjects,
  ) async {
    final titleCtrl = TextEditingController();
    final courseCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final prepCtrl = TextEditingController();
    var due = DateTime.now().add(const Duration(days: 7));
    var dueTime = TimeOfDay(hour: due.hour, minute: due.minute);
    if (dueTime.hour == 0 && dueTime.minute == 0) {
      dueTime = const TimeOfDay(hour: 17, minute: 0);
    }
    var type = AssessmentType.assignment;
    String? subjectId = widget.focusSubjectId;
    if (subjectId != null) {
      for (final s in subjects) {
        if (s.id == subjectId) {
          courseCtrl.text = s.label;
          break;
        }
      }
    }
    var showAdvanced = false;
    final tz = DateTime.now().timeZoneName;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final t = DesignTokens.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick create',
                        style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courseCtrl,
                      decoration: const InputDecoration(labelText: 'Course'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AssessmentType>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: AssessmentType.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ))
                          .toList(),
                      onChanged: (v) => setLocal(() => type = v ?? type),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Due ${MaterialLocalizations.of(ctx).formatMediumDate(due)} · ${dueTime.format(ctx)}',
                      ),
                      subtitle: Text('Timezone: $tz (never hidden)'),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: due,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (d == null) return;
                        if (!ctx.mounted) return;
                        final tm = await showTimePicker(
                          context: ctx,
                          initialTime: dueTime,
                        );
                        setLocal(() {
                          due = d;
                          if (tm != null) dueTime = tm;
                        });
                      },
                    ),
                    TextButton(
                      onPressed: () =>
                          setLocal(() => showAdvanced = !showAdvanced),
                      child: Text(
                        showAdvanced ? 'Hide advanced' : 'Show advanced',
                      ),
                    ),
                    if (showAdvanced) ...[
                      TextField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight % (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: prepCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Est. prep minutes (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (subjects.isNotEmpty)
                        DropdownButtonFormField<String?>(
                          value: subjectId,
                          decoration:
                              const InputDecoration(labelText: 'Subject'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None'),
                            ),
                            ...subjects.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.label),
                              ),
                            ),
                          ],
                          onChanged: (v) => setLocal(() => subjectId = v),
                        ),
                    ],
                    const SizedBox(height: 16),
                    SgPrimaryButton(
                      label: 'Create',
                      expanded: true,
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty ||
                            courseCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                    ),
                    SizedBox(height: t.gap(1)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final dueDateTime = DateTime(
      due.year,
      due.month,
      due.day,
      dueTime.hour,
      dueTime.minute,
    );
    await widget.assessmentService.addAssessment(
      course: courseCtrl.text.trim(),
      title: titleCtrl.text.trim(),
      dueDate: dueDateTime,
      subjectId: subjectId,
      type: type,
      weightPercent: double.tryParse(weightCtrl.text.trim()),
      estimatedPrepMinutes: int.tryParse(prepCtrl.text.trim()),
      timeZoneId: tz,
    );
  }
}

Color _pressureColor(DesignTokens t, ReadinessState s) => switch (s) {
      ReadinessState.onTrack => t.pressureCalm,
      ReadinessState.needsAttention => t.pressureWatch,
      ReadinessState.timeIsTight => t.pressureTight,
      ReadinessState.missingInformation => t.pressureMissing,
    };

IconData _pressureIcon(ReadinessState s) {
  if (themeController.style == VisualStyleFamily.naturalistic) {
    return Icons.spa_outlined;
  }
  return switch (s) {
    ReadinessState.onTrack => Icons.check_circle_outline,
    ReadinessState.needsAttention => Icons.visibility_outlined,
    ReadinessState.timeIsTight => Icons.schedule,
    ReadinessState.missingInformation => Icons.help_outline,
  };
}


class _AssessmentDecisionCard extends StatelessWidget {
  const _AssessmentDecisionCard({
    required this.assessment,
    required this.evidence,
    required this.subject,
    required this.nextAction,
    required this.onOpen,
  });

  final Assessment assessment;
  final ReadinessEvidence evidence;
  final Subject? subject;
  final String nextAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _pressureColor(t, evidence.state);

    return SgCard(
      onTap: onOpen,
      accent: color.withValues(alpha: 0.4),
      semanticLabel:
          '${assessment.title}, ${evidence.state.calmLabel}, ${assessment.dueLabel}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: StyleAssessmentMark(
              size: 26,
              color: color,
              progress: assessment.progress,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MathText(
                        assessment.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SgStatusTag(
                      label: evidence.state.calmLabel,
                      color: color,
                      icon: _pressureIcon(evidence.state),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${subject?.label ?? assessment.course} · ${assessment.type.label}',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    assessment.dueLabel,
                    if (assessment.weightPercent != null)
                      '${assessment.weightPercent!.round()}% weight',
                    if (evidence.estimatedPrepRemainingMinutes != null)
                      '~${evidence.estimatedPrepRemainingMinutes} min left',
                  ].join(' · '),
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: assessment.progress.clamp(0, 1),
                    minHeight: 8,
                    color: color,
                    backgroundColor: t.bgMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next: $nextAction',
                  style: TextStyle(color: t.textPrimary, fontSize: 13),
                ),
                if (assessment.linkedTopicIds.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${assessment.linkedTopicIds.length} linked topic(s)',
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
