import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/lecture_lab_service.dart';
import '../services/note_service.dart';
import '../services/subject_service.dart';
import '../theme/design_tokens.dart';
import '../theme/style_family.dart';
import '../main.dart';
import '../ui/assessment_materials.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';
import '../ui/shell_scope.dart';
import '../utils/datetime_utils.dart';

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage({
    super.key,
    required this.panelOpacity,
    required this.onOpacityChanged,
    required this.assessmentService,
    required this.onOpenAssessment,
    this.subjectService,
    this.lectureLabService,
    this.noteService,
    this.onContinuePreparation,
    this.focusSubjectId,
  });

  final double panelOpacity;
  final ValueChanged<double> onOpacityChanged;
  final AssessmentService assessmentService;
  final SubjectService? subjectService;
  final LectureLabService? lectureLabService;
  final NoteService? noteService;
  final void Function(Assessment assessment) onOpenAssessment;
  final void Function(Assessment assessment)? onContinuePreparation;
  final String? focusSubjectId;

  @override
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  late final Stream<List<Assessment>> _assessmentsStream;
  bool _showCompleted = false;

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
    final active = scoped.where((a) => a.isActive).toList();
    final done = scoped.where((a) => !a.isActive).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final shown = _showCompleted ? done : active;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showCompleted ? 'Completed' : 'Assessments',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: t.gap(0.5)),
                      Text(
                        _showCompleted
                            ? 'Bring one back whenever you need it'
                            : 'Soonest due dates first',
                        style: TextStyle(
                          color: t.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: done.isEmpty && !_showCompleted
                      ? null
                      : () => setState(() => _showCompleted = !_showCompleted),
                  child: Text(
                    _showCompleted
                        ? 'Active'
                        : (done.isEmpty
                            ? 'Completed'
                            : 'Completed (${done.length})'),
                  ),
                ),
                if (!_showCompleted) ...[
                  SizedBox(width: t.gap(1)),
                  SgPrimaryButton(
                    label: 'Create',
                    icon: Icons.add,
                    onPressed: () => _quickCreate(context, subjects),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: t.gap(2))),
        if (shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: SgEmptyState(
              title: _showCompleted ? 'Nothing completed yet' : 'No assessments',
              body: _showCompleted
                  ? 'Mark an assessment complete to archive it here.'
                  : 'Create one with a due date.',
              action: _showCompleted
                  ? SgSecondaryButton(
                      label: 'Back to assessments',
                      onPressed: () => setState(() => _showCompleted = false),
                    )
                  : SgPrimaryButton(
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
              itemCount: shown.length,
              separatorBuilder: (_, _) => SizedBox(height: t.gap(1.5)),
              itemBuilder: (context, i) {
                final a = shown[i];
                return _AssessmentDecisionCard(
                  assessment: a,
                  subject:
                      a.subjectId == null ? null : subjectById[a.subjectId!],
                  archived: !a.isActive,
                  onOpen: () => widget.onOpenAssessment(a),
                  onRestore: _showCompleted
                      ? () => widget.assessmentService.restoreAssessment(a.id)
                      : null,
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
    final tz = DateTime.now().timeZoneName;
    var createError = '';
    final pending = <PendingAssessmentMaterial>[];
    var materialsBusy = false;

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
                    Text(
                      'New assessment',
                      style: Theme.of(ctx).textTheme.headlineSmall,
                    ),
                    SizedBox(height: t.gap(0.5)),
                    Text(
                      'Name, course, type and due date are saved with the card.',
                      style: TextStyle(color: t.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: courseCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Course'),
                    ),
                    const SizedBox(height: 12),
                    if (subjects.isEmpty)
                      Text(
                        'Add a subject in Subjects to link this assessment and its timer to Time.',
                        style: TextStyle(color: t.textMuted, fontSize: 13),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        value: subjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
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
                        onChanged: (v) {
                          setLocal(() {
                            subjectId = v;
                            if (v != null) {
                              for (final s in subjects) {
                                if (s.id == v &&
                                    courseCtrl.text.trim().isEmpty) {
                                  courseCtrl.text = s.label;
                                  break;
                                }
                              }
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Due ${MaterialLocalizations.of(ctx).formatMediumDate(due)} · ${dueTime.format(ctx)}',
                      ),
                      subtitle: Text(tz),
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
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight %',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: prepCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prep minutes',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Materials',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    AssessmentMaterialsActions(
                      busy: materialsBusy,
                      onUpload: () async {
                        setLocal(() => materialsBusy = true);
                        try {
                          final added = await pickAssessmentUploads();
                          if (added.isEmpty) return;
                          setLocal(() {
                            for (final item in added) {
                              if (pending.any(
                                (e) =>
                                    e.attachment.linkKey ==
                                    item.attachment.linkKey,
                              )) {
                                continue;
                              }
                              pending.add(item);
                            }
                          });
                        } finally {
                          if (ctx.mounted) {
                            setLocal(() => materialsBusy = false);
                          }
                        }
                      },
                      onPickExisting: () async {
                        setLocal(() => materialsBusy = true);
                        try {
                          final picked = await _pickExistingMaterials(
                            ctx,
                            already: pending
                                .map((e) => e.attachment.linkKey)
                                .toSet(),
                          );
                          if (picked.isEmpty) return;
                          setLocal(() {
                            for (final att in picked) {
                              if (pending.any(
                                (e) => e.attachment.linkKey == att.linkKey,
                              )) {
                                continue;
                              }
                              pending.add(
                                PendingAssessmentMaterial(attachment: att),
                              );
                            }
                          });
                        } finally {
                          if (ctx.mounted) {
                            setLocal(() => materialsBusy = false);
                          }
                        }
                      },
                    ),
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AssessmentPendingChips(
                        pending: pending,
                        onRemove: (item) =>
                            setLocal(() => pending.remove(item)),
                      ),
                    ],
                    if (createError.isNotEmpty) ...[
                      Text(
                        createError,
                        style: TextStyle(color: t.destructive, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    SgPrimaryButton(
                      label: 'Create',
                      expanded: true,
                      onPressed: () {
                        var course = courseCtrl.text.trim();
                        if (course.isEmpty && subjectId != null) {
                          for (final s in subjects) {
                            if (s.id == subjectId) {
                              course = s.label;
                              courseCtrl.text = course;
                              break;
                            }
                          }
                        }
                        if (titleCtrl.text.trim().isEmpty || course.isEmpty) {
                          setLocal(
                            () => createError =
                                'Add a name and course to create.',
                          );
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

    if (ok != true) {
      titleCtrl.dispose();
      courseCtrl.dispose();
      weightCtrl.dispose();
      prepCtrl.dispose();
      return;
    }
    final dueDateTime = DateTime(
      due.year,
      due.month,
      due.day,
      dueTime.hour,
      dueTime.minute,
    );
    var course = courseCtrl.text.trim();
    if (course.isEmpty && subjectId != null) {
      for (final s in subjects) {
        if (s.id == subjectId) {
          course = s.label;
          break;
        }
      }
    }
    final id = await widget.assessmentService.addAssessment(
      course: course,
      title: titleCtrl.text.trim(),
      dueDate: dueDateTime,
      subjectId: subjectId,
      type: type,
      weightPercent: double.tryParse(weightCtrl.text.trim()),
      estimatedPrepMinutes: int.tryParse(prepCtrl.text.trim()),
      timeZoneId: tz,
    );
    if (pending.isNotEmpty) {
      await _persistPendingMaterials(id, pending);
    }
    titleCtrl.dispose();
    courseCtrl.dispose();
    weightCtrl.dispose();
    prepCtrl.dispose();
  }

  Future<void> _persistPendingMaterials(
    String assessmentId,
    List<PendingAssessmentMaterial> pending,
  ) async {
    final links = <AssessmentAttachment>[];
    for (final item in pending) {
      if (item.needsUpload) {
        try {
          await widget.assessmentService.attachUploadedFile(
            assessmentId: assessmentId,
            filename: item.attachment.name,
            sourcePath: item.sourcePath,
            bytes: item.bytes,
          );
        } catch (_) {}
      } else {
        links.add(item.attachment);
      }
    }
    if (links.isNotEmpty) {
      await widget.assessmentService.attachLinks(assessmentId, links);
    }
  }

  Future<List<AssessmentAttachment>> _pickExistingMaterials(
    BuildContext context, {
    required Set<String> already,
  }) async {
    final lab = widget.lectureLabService;
    final notes = widget.noteService;
    try {
      final lectures = lab == null
          ? const <LectureNote>[]
          : await lab.streamLectures().first;
      final noteItems = notes == null
          ? const <NoteItem>[]
          : await notes.streamNotes().first;
      final assessments =
          await widget.assessmentService.streamAssessments().first;
      if (!context.mounted) return const [];
      return showAssessmentLibraryPicker(
        context: context,
        lectures: lectures,
        notes: noteItems,
        libraryFiles: libraryFilesFrom(assessments),
        alreadyLinked: already,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load saved files: $e')),
        );
      }
      return const [];
    }
  }
}

class _AssessmentDecisionCard extends StatelessWidget {
  const _AssessmentDecisionCard({
    required this.assessment,
    required this.subject,
    required this.onOpen,
    this.archived = false,
    this.onRestore,
  });

  final Assessment assessment;
  final Subject? subject;
  final VoidCallback onOpen;
  final bool archived;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final course = (subject?.label ?? assessment.course).trim();
    final openTask = assessment.subtasks.where((s) => !s.done);
    final dueFact = formatDueDateTime(
      context,
      assessment.dueDate,
      timeZoneId: assessment.timeZoneId,
    );
    final facts = <String>[
      if (assessment.weightPercent != null)
        '${assessment.weightPercent!.round()}% weight',
      if (assessment.estimatedPrepMinutes != null)
        '~${assessment.estimatedPrepMinutes} min prep',
      if (assessment.attachments.isNotEmpty)
        '${assessment.attachments.length} '
            '${assessment.attachments.length == 1 ? 'material' : 'materials'}',
    ];

    return SgCard(
      onTap: onOpen,
      semanticLabel:
          '${assessment.title}, ${archived ? 'Completed' : assessment.type.label}, $dueFact',
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
              if (archived)
                SgStatusTag(
                  label: 'Completed',
                  color: t.textMuted,
                  icon: Icons.inventory_2_outlined,
                ),
            ],
          ),
          if (course.isNotEmpty || assessment.type != AssessmentType.other) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (course.isNotEmpty) course,
                assessment.type.label,
              ].join(' · '),
              style: TextStyle(color: t.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            dueFact,
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final fact in facts)
                  _FactChip(label: fact, color: t.decorationAccent),
              ],
            ),
          ],
          if (assessment.subtasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: assessment.progress.clamp(0, 1),
                minHeight: 8,
                color: t.decorationAccent,
                backgroundColor: t.bgMuted,
              ),
            ),
          ],
          if (archived) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SgSecondaryButton(
                label: 'Bring back',
                icon: Icons.unarchive_outlined,
                onPressed: onRestore,
              ),
            ),
          ] else if (openTask.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Next: ${openTask.first.title}',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.radiusXl),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: t.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
