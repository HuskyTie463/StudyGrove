import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/readiness_engine.dart';
import '../services/subject_service.dart';
import '../theme/design_tokens.dart';
import '../theme/style_family.dart';
import '../main.dart';
import '../ui/sg_primitives.dart';
import '../ui/style_motifs.dart';

enum _Filter {
  all,
  thisWeek,
  exams,
  assignments,
  reportsLabs,
  completed,
}

enum _Sort {
  recommended,
  due,
  weight,
  remaining,
  course,
}

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage({
    super.key,
    required this.panelOpacity,
    required this.onOpacityChanged,
    required this.assessmentService,
    required this.onOpenAssessment,
    this.subjectService,
    this.onContinuePreparation,
  });

  final double panelOpacity;
  final ValueChanged<double> onOpacityChanged;
  final AssessmentService assessmentService;
  final SubjectService? subjectService;
  final void Function(Assessment assessment) onOpenAssessment;
  final void Function(Assessment assessment)? onContinuePreparation;

  @override
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  late final Stream<List<Assessment>> _assessmentsStream;
  final _engine = const AssessmentReadinessEngine();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.recommended;

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
    final subjectById = {for (final s in subjects) s.id: s};
    final hero = _engine.mostImportant(assessments);
    final active = assessments.where((a) => a.isActive).toList();
    final filtered = _applyFilter(assessments);
    final sorted = _applySort(filtered);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 48,
            isPhone ? 20 : 32,
            isPhone ? 16 : 48,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SgSectionHeader(
                eyebrow: 'Assessments',
                title: 'What needs you next',
                subtitle:
                    'Evidence-informed readiness — not a predicted grade.',
              ),
              SizedBox(height: t.gap(2.5)),
              if (hero != null)
                _ReadinessHero(
                  assessment: hero,
                  evidence: _engine.explain(hero),
                  subject: hero.subjectId == null
                      ? null
                      : subjectById[hero.subjectId!],
                  onContinue: () {
                    (widget.onContinuePreparation ?? widget.onOpenAssessment)(
                      hero,
                    );
                  },
                  onEdit: () => widget.onOpenAssessment(hero),
                )
              else
                SgEmptyState(
                  title: 'No upcoming assessments',
                  body:
                      'Add one with a due date and time so Study Grove can plan preparation.',
                  action: SgPrimaryButton(
                    label: 'Quick create',
                    icon: Icons.add,
                    onPressed: () => _quickCreate(context, subjects),
                  ),
                ),
              if (hero != null) ...[
                SizedBox(height: t.gap(3)),
                _Runway(
                  assessment: hero,
                  motif: themeController.style.runwayMotif,
                ),
                SizedBox(height: t.gap(3)),
                _BestNextAction(
                  action: _engine.bestNextAction(hero, _engine.explain(hero)),
                  onGo: () => widget.onOpenAssessment(hero),
                ),
              ],
              SizedBox(height: t.gap(3)),
              _PressureMap(
                assessments: active,
                engine: _engine,
                subjectById: subjectById,
                onOpen: widget.onOpenAssessment,
              ),
              SizedBox(height: t.gap(3)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All assessments',
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
              SizedBox(height: t.gap(1.5)),
              _FilterBar(
                filter: _filter,
                sort: _sort,
                onFilter: (f) => setState(() => _filter = f),
                onSort: (s) => setState(() => _sort = s),
              ),
              SizedBox(height: t.gap(2)),
            ]),
          ),
        ),
        if (sorted.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: SgEmptyState(
              title: 'Nothing in this filter',
              body: 'Try another filter or create an assessment.',
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
              itemCount: sorted.length,
              separatorBuilder: (_, _) => SizedBox(height: t.gap(1.5)),
              itemBuilder: (context, i) {
                final a = sorted[i];
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

  List<Assessment> _applyFilter(List<Assessment> all) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    return all.where((a) {
      switch (_filter) {
        case _Filter.all:
          return a.isActive;
        case _Filter.thisWeek:
          return a.isActive &&
              !a.dueDate.isBefore(now.subtract(const Duration(days: 1))) &&
              !a.dueDate.isAfter(weekEnd);
        case _Filter.exams:
          return a.isActive && a.type == AssessmentType.exam;
        case _Filter.assignments:
          return a.isActive && a.type == AssessmentType.assignment;
        case _Filter.reportsLabs:
          return a.isActive && a.type == AssessmentType.reportLab;
        case _Filter.completed:
          return a.completed || a.archived;
      }
    }).toList();
  }

  List<Assessment> _applySort(List<Assessment> list) {
    final copy = [...list];
    switch (_sort) {
      case _Sort.recommended:
        copy.sort((a, b) => _engine
            .explain(b)
            .priorityScore
            .compareTo(_engine.explain(a).priorityScore));
      case _Sort.due:
        copy.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case _Sort.weight:
        copy.sort((a, b) =>
            (b.weightPercent ?? -1).compareTo(a.weightPercent ?? -1));
      case _Sort.remaining:
        copy.sort((a, b) {
          final ra = _engine.explain(a).estimatedPrepRemainingMinutes ?? 99999;
          final rb = _engine.explain(b).estimatedPrepRemainingMinutes ?? 99999;
          return rb.compareTo(ra);
        });
      case _Sort.course:
        copy.sort((a, b) => a.course.compareTo(b.course));
    }
    return copy;
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
    String? subjectId;
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

class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({
    required this.assessment,
    required this.evidence,
    required this.subject,
    required this.onContinue,
    required this.onEdit,
  });

  final Assessment assessment;
  final ReadinessEvidence evidence;
  final Subject? subject;
  final VoidCallback onContinue;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _pressureColor(t, evidence.state);
    final dueTime = TimeOfDay.fromDateTime(assessment.dueDate);

    return SgCard(
      accent: color.withValues(alpha: 0.55),
      semanticLabel:
          'Most important: ${assessment.title}. ${evidence.state.calmLabel}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'READINESS HERO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: t.textMuted,
            ),
          ),
          SizedBox(height: t.gap(1)),
          Text(
            assessment.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: t.gap(0.75)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SgStatusTag(
                label: subject?.label ?? assessment.course,
                color: subject?.color ?? t.secondaryAccent,
              ),
              SgStatusTag(label: assessment.type.label, color: t.textMuted),
              SgStatusTag(
                label: evidence.state.calmLabel,
                color: color,
                icon: _pressureIcon(evidence.state),
              ),
            ],
          ),
          SizedBox(height: t.gap(1.5)),
          Text(
            '${assessment.dueLabel} · ${MaterialLocalizations.of(context).formatMediumDate(assessment.dueDate)} ${dueTime.format(context)}'
            '${assessment.timeZoneId != null ? ' (${assessment.timeZoneId})' : ''}',
            style: TextStyle(color: t.textSecondary),
          ),
          SizedBox(height: t.gap(0.5)),
          Text(
            [
              if (assessment.weightPercent != null)
                'Weight ${assessment.weightPercent!.round()}%',
              if (evidence.estimatedPrepRemainingMinutes != null)
                '~${evidence.estimatedPrepRemainingMinutes} min prep remaining',
              '${assessment.daysUntilDue} day(s) left',
            ].join(' · '),
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
          SizedBox(height: t.gap(1.5)),
          Text(
            evidence.summary,
            style: TextStyle(color: t.textSecondary, height: 1.45),
          ),
          SizedBox(height: t.gap(1)),
          ...evidence.factors.take(4).map(
                (f) => Padding(
                  padding: EdgeInsets.only(bottom: t.gap(0.5)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ', style: TextStyle(color: t.textMuted)),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: t.textMuted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          SizedBox(height: t.gap(2)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SgPrimaryButton(
                label: 'Continue preparation',
                icon: Icons.play_arrow_rounded,
                onPressed: onContinue,
              ),
              SgSecondaryButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Runway extends StatelessWidget {
  const _Runway({required this.assessment, required this.motif});

  final Assessment assessment;
  final String motif;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final days = assessment.daysUntilDue.clamp(0, 60);
    final milestones = <_Mile>[
      _Mile('Today', 0, Icons.today_outlined),
      _Mile('Prep tasks', (days * 0.35).round(), Icons.checklist_outlined),
      _Mile('Review window', (days * 0.65).round(), Icons.psychology_outlined),
      _Mile('Submission check', (days * 0.9).round(), Icons.fact_check_outlined),
      _Mile('Due', days, Icons.flag_outlined),
    ];

    return SgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Runway · ${motif == 'vine' ? 'growing path' : motif}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: t.textSecondary,
            ),
          ),
          SizedBox(height: t.gap(1.5)),
          ...milestones.map((m) {
            return Padding(
              padding: EdgeInsets.only(bottom: t.gap(1.25)),
              child: Row(
                children: [
                  _motifMark(t, motif),
                  SizedBox(width: t.gap(1.25)),
                  Icon(m.icon, size: 18, color: t.textMuted),
                  SizedBox(width: t.gap(1)),
                  Expanded(
                    child: Text(
                      m.label,
                      style: TextStyle(color: t.textPrimary),
                    ),
                  ),
                  Text(
                    m.offsetDays == 0 ? 'now' : '+${m.offsetDays}d',
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
          if (assessment.daysUntilDue <= 3)
            SgStatusTag(
              label: 'Pressure warning — due soon',
              color: t.pressureTight,
              icon: Icons.warning_amber_outlined,
            ),
        ],
      ),
    );
  }

  Widget _motifMark(DesignTokens t, String motif) {
    switch (motif) {
      case 'vine':
        return StyleAssessmentMark(size: 18, color: t.decorationAccent);
      case 'stones':
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: t.decorationAccent,
            shape: BoxShape.circle,
          ),
        );
      case 'blocks':
        return Container(
          width: 12,
          height: 12,
          color: t.primaryAction,
        );
      case 'illuminated':
        return Icon(Icons.auto_awesome, size: 16, color: t.secondaryAccent);
      case 'line':
        return Container(
          width: 10,
          height: 2,
          color: t.textMuted,
        );
      default:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: t.primaryAction, width: 2),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}

class _Mile {
  const _Mile(this.label, this.offsetDays, this.icon);
  final String label;
  final int offsetDays;
  final IconData icon;
}

class _BestNextAction extends StatelessWidget {
  const _BestNextAction({required this.action, required this.onGo});
  final String action;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SgCard(
      onTap: onGo,
      accent: t.primaryAction.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.bolt_outlined, color: t.primaryAction),
          SizedBox(width: t.gap(1.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best next action',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: t.textMuted,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: t.gap(0.5)),
                Text(action, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textMuted),
        ],
      ),
    );
  }
}

class _PressureMap extends StatelessWidget {
  const _PressureMap({
    required this.assessments,
    required this.engine,
    required this.subjectById,
    required this.onOpen,
  });

  final List<Assessment> assessments;
  final AssessmentReadinessEngine engine;
  final Map<String, Subject> subjectById;
  final void Function(Assessment) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final byCourse = <String, List<Assessment>>{};
    for (final a in assessments) {
      byCourse.putIfAbsent(a.course, () => []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pressure map', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: t.gap(0.75)),
        Text(
          'Urgency, weight, remaining prep and readiness — labels included, not colour alone.',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        SizedBox(height: t.gap(1.5)),
        if (byCourse.isEmpty)
          Text('No active courses yet.', style: TextStyle(color: t.textMuted))
        else
          ...byCourse.entries.map((e) {
            final worst = e.value
                .map((a) => engine.explain(a))
                .reduce((a, b) =>
                    a.priorityScore >= b.priorityScore ? a : b);
            final sample = e.value.first;
            return Padding(
              padding: EdgeInsets.only(bottom: t.gap(1)),
              child: SgCard(
                onTap: () => onOpen(sample),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _pressureColor(t, worst.state),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: t.gap(1.5)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            '${e.value.length} assessment(s) · ${worst.state.calmLabel}',
                            style: TextStyle(color: t.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SgStatusTag(
                      label: worst.state.calmLabel,
                      color: _pressureColor(t, worst.state),
                      icon: _pressureIcon(worst.state),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.sort,
    required this.onFilter,
    required this.onSort,
  });

  final _Filter filter;
  final _Sort sort;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _Filter.values.map((f) {
              final selected = filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_filterLabel(f)),
                  selected: selected,
                  onSelected: (_) => onFilter(f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<_Sort>(
            value: sort,
            items: _Sort.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(_sortLabel(s)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onSort(v);
            },
          ),
        ),
      ],
    );
  }

  String _filterLabel(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.thisWeek => 'This week',
        _Filter.exams => 'Exams',
        _Filter.assignments => 'Assignments',
        _Filter.reportsLabs => 'Reports / labs',
        _Filter.completed => 'Completed',
      };

  String _sortLabel(_Sort s) => switch (s) {
        _Sort.recommended => 'Sort: Recommended',
        _Sort.due => 'Sort: Due',
        _Sort.weight => 'Sort: Weight',
        _Sort.remaining => 'Sort: Remaining',
        _Sort.course => 'Sort: Course',
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
                      child: Text(
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
