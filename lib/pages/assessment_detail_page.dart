import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/lecture_lab_service.dart';
import '../services/note_service.dart';
import '../services/study_time_service.dart';
import '../services/subject_service.dart';
import '../theme/design_tokens.dart';
import '../ui/assessment_materials.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';
import '../utils/datetime_utils.dart';

class AssessmentDetailPage extends StatefulWidget {
  const AssessmentDetailPage({
    super.key,
    required this.panelOpacity,
    required this.assessment,
    required this.service,
    required this.studyTimeService,
    this.subjectService,
    this.lectureLabService,
    this.noteService,
  });

  final double panelOpacity;
  final Assessment assessment;
  final AssessmentService service;
  final StudyTimeService studyTimeService;
  final SubjectService? subjectService;
  final LectureLabService? lectureLabService;
  final NoteService? noteService;

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  late Assessment a;
  final _notesCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _reflectionCtrl = TextEditingController();
  bool _materialsBusy = false;

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
    final svc = widget.studyTimeService;
    if (svc.activeAssessmentId == a.id) {
      unawaited(svc.stopAssessmentSession());
    }
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

  Future<void> _setSubject(String? id) async {
    final next = (id == null || id.isEmpty)
        ? a.copyWith(clearSubject: true)
        : a.copyWith(subjectId: id);
    await _persist(next);
    if (widget.studyTimeService.activeAssessmentId == next.id) {
      await widget.studyTimeService.retargetAssessmentSessionSubject(
        next.subjectId,
      );
    }
  }

  Future<void> _openFullscreenTimer() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenStudyTimerPage(
          studyTimeService: widget.studyTimeService,
          assessmentOf: () => a,
          onSaved: (seconds) {
            if (!mounted || seconds <= 0) return;
            setState(() {
              a = a.copyWith(spentSeconds: a.spentSeconds + seconds);
            });
          },
        ),
      ),
    );
  }

  List<_Fact> _facts() {
    final facts = <_Fact>[];
    if (a.weightPercent != null) {
      facts.add(_Fact('${a.weightPercent!.round()}% of course'));
    }
    if (a.estimatedPrepMinutes != null) {
      facts.add(_Fact('~${a.estimatedPrepMinutes} min prep'));
    }
    if (a.subtasks.isNotEmpty) {
      final done = a.subtasks.where((s) => s.done).length;
      facts.add(_Fact('$done/${a.subtasks.length} prep tasks'));
    }
    if (a.attachments.isNotEmpty) {
      facts.add(
        _Fact(
          '${a.attachments.length} '
          '${a.attachments.length == 1 ? 'material' : 'materials'}',
        ),
      );
    }
    return facts;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final course = a.course.trim();
    final notes = _notesCtrl.text.trim();
    final facts = _facts();

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        t.gap(2.5),
        t.gap(1.5),
        t.gap(2.5),
        t.gap(4),
      ),
      children: [
        SgSectionHeader(
          eyebrow: course.isNotEmpty ? course : a.type.label,
          title: a.title,
          subtitle: formatDueDateTime(
            context,
            a.dueDate,
            timeZoneId: a.timeZoneId,
            fullDate: true,
          ),
        ),
        SizedBox(height: t.gap(2)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SgStatusTag(label: a.type.label, color: t.secondaryAccent),
            if (a.completed || a.archived)
              SgStatusTag(
                label: 'Completed',
                color: t.textMuted,
                icon: Icons.inventory_2_outlined,
              ),
            for (final fact in facts)
              SgStatusTag(label: fact.label, color: t.decorationAccent),
          ],
        ),
        SizedBox(height: t.gap(2.5)),
        StreamBuilder<List<Subject>>(
          stream: widget.subjectService?.streamSubjects(),
          builder: (context, snap) {
            final subjects = snap.data ?? const <Subject>[];
            return _AssessmentSubjectPicker(
              subjects: subjects,
              subjectId: a.subjectId,
              onChanged: _setSubject,
            );
          },
        ),
        SizedBox(height: t.gap(2)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prep tasks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSubtask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (a.subtasks.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: t.gap(0.5)),
                  child: Text(
                    'Break the work into small steps when you are ready.',
                    style: TextStyle(color: t.textMuted, height: 1.45),
                  ),
                )
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
              Text(
                'Weight & prep',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: t.gap(1.5)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 420;
                  final weightField = TextField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight %',
                    ),
                  );
                  final prepField = TextField(
                    controller: _prepCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prep minutes',
                    ),
                  );
                  if (!sideBySide) {
                    return Column(
                      children: [
                        weightField,
                        SizedBox(height: t.gap(1)),
                        prepField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: weightField),
                      SizedBox(width: t.gap(1.5)),
                      Expanded(child: prepField),
                    ],
                  );
                },
              ),
              SizedBox(height: t.gap(2)),
              Text('Confidence', style: TextStyle(color: t.textSecondary)),
              Slider(
                value: a.confidence ?? 0.5,
                onChanged: (v) => setState(
                  () => a = a.copyWith(confidence: v),
                ),
                onChangeEnd: (v) => _persist(a.copyWith(confidence: v)),
              ),
              if (a.confidence != null)
                Text(
                  '${(a.confidence! * 100).round()}%',
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
                onChanged: (v) => setState(() => a = a.copyWith(notes: v)),
              ),
              if (notes.isNotEmpty) ...[
                SizedBox(height: t.gap(1)),
                MathText(
                  notes,
                  style: TextStyle(color: t.textSecondary, height: 1.45),
                ),
              ],
              SizedBox(height: t.gap(1)),
              SgSecondaryButton(
                label: 'Save notes',
                onPressed: () => _persist(a.copyWith(notes: _notesCtrl.text)),
              ),
            ],
          ),
        ),
        if (a.attachments.isNotEmpty) ...[
          SizedBox(height: t.gap(2)),
          SgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Materials',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AssessmentAttachmentList(
                  attachments: a.attachments,
                  onOpen: _openAttachment,
                  onRemove: _removeAttachment,
                ),
              ],
            ),
          ),
        ],
        if (a.completed || a.archived) ...[
          SizedBox(height: t.gap(2)),
          SgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archive reflection',
                  style: Theme.of(context).textTheme.titleMedium,
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
        ],
        SizedBox(height: t.gap(2.5)),
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
              )
            else
              SgPrimaryButton(
                label: 'Bring back',
                icon: Icons.unarchive_outlined,
                onPressed: () async {
                  await widget.service.restoreAssessment(a.id);
                  if (context.mounted) {
                    setState(() {
                      a = a.copyWith(completed: false, archived: false);
                    });
                  }
                },
              ),
            SgSecondaryButton(
              label: _materialsBusy ? 'Adding…' : 'Upload files',
              icon: Icons.upload_file_outlined,
              onPressed: _materialsBusy ? null : () { _uploadFiles(); },
            ),
            SgSecondaryButton(
              label: 'Pick lectures / files',
              icon: Icons.library_add_outlined,
              onPressed: _materialsBusy ? null : () { _pickExisting(); },
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
        SizedBox(height: t.gap(3)),
        _AssessmentStudyTimer(
          assessment: a,
          studyTimeService: widget.studyTimeService,
          onFullScreen: _openFullscreenTimer,
          onSaved: (seconds) {
            if (!mounted || seconds <= 0) return;
            setState(() {
              a = a.copyWith(spentSeconds: a.spentSeconds + seconds);
            });
          },
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(isWide ? 'Assessment' : a.title),
        backgroundColor: t.bgElevated,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: body,
        ),
      ),
    );
  }

  Future<void> _uploadFiles() async {
    setState(() => _materialsBusy = true);
    try {
      final added = await pickAssessmentUploads();
      for (final item in added) {
        if (!item.needsUpload) continue;
        final stored = await widget.service.attachUploadedFile(
          assessmentId: a.id,
          filename: item.attachment.name,
          sourcePath: item.sourcePath,
          bytes: item.bytes,
        );
        if (!mounted) return;
        setState(() {
          if (!a.attachments.any((e) => e.linkKey == stored.linkKey)) {
            a = a.copyWith(attachments: [...a.attachments, stored]);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _materialsBusy = false);
    }
  }

  Future<void> _pickExisting() async {
    setState(() => _materialsBusy = true);
    try {
      final lab = widget.lectureLabService;
      final notes = widget.noteService;
      final lectures = lab == null
          ? const <LectureNote>[]
          : await lab.streamLectures().first;
      final noteItems = notes == null
          ? const <NoteItem>[]
          : await notes.streamNotes().first;
      final assessments = await widget.service.streamAssessments().first;
      if (!mounted) return;
      final picked = await showAssessmentLibraryPicker(
        context: context,
        lectures: lectures,
        notes: noteItems,
        libraryFiles: libraryFilesFrom(assessments),
        alreadyLinked: a.attachments.map((e) => e.linkKey).toSet(),
      );
      if (picked.isEmpty) return;
      await widget.service.attachLinks(a.id, picked);
      if (!mounted) return;
      setState(() {
        final keys = a.attachments.map((e) => e.linkKey).toSet();
        a = a.copyWith(
          attachments: [
            ...a.attachments,
            ...picked.where((e) => keys.add(e.linkKey)),
          ],
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not link materials: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _materialsBusy = false);
    }
  }

  Future<void> _openAttachment(AssessmentAttachment att) {
    return openAssessmentAttachment(
      context: context,
      att: att,
      lectureLab: widget.lectureLabService,
      notes: widget.noteService,
    );
  }

  Future<void> _removeAttachment(AssessmentAttachment att) async {
    await widget.service.removeAttachment(a.id, att);
    if (!mounted) return;
    setState(() {
      a = a.copyWith(
        attachments: a.attachments.where((e) => e.id != att.id).toList(),
      );
    });
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
    ctrl.dispose();
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

class _Fact {
  const _Fact(this.label);
  final String label;
}

class _AssessmentSubjectPicker extends StatelessWidget {
  const _AssessmentSubjectPicker({
    required this.subjects,
    required this.subjectId,
    required this.onChanged,
  });

  final List<Subject> subjects;
  final String? subjectId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ids = {for (final s in subjects) s.id};
    final stale = subjectId != null &&
        subjectId!.isNotEmpty &&
        !ids.contains(subjectId);
    final selected = (subjectId != null &&
            subjectId!.isNotEmpty &&
            (ids.contains(subjectId) || stale))
        ? subjectId
        : null;
    return SgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Subject', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: t.gap(0.5)),
          Text(
            'The study timer adds Stop time to this subject on Time.',
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
          SizedBox(height: t.gap(1.5)),
          if (subjects.isEmpty)
            Text(
              'Add a subject in Subjects to pick one here.',
              style: TextStyle(color: t.textMuted, fontSize: 13),
            )
          else
            DropdownButtonFormField<String?>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None'),
                ),
                if (stale)
                  DropdownMenuItem(
                    value: subjectId,
                    child: Text('Saved subject'),
                  ),
                ...subjects.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.label),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _AssessmentStudyTimer extends StatelessWidget {
  const _AssessmentStudyTimer({
    required this.assessment,
    required this.studyTimeService,
    required this.onSaved,
    required this.onFullScreen,
  });

  final Assessment assessment;
  final StudyTimeService studyTimeService;
  final ValueChanged<int> onSaved;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: studyTimeService,
      builder: (context, _) {
        final live = studyTimeService.isAssessmentLive &&
            studyTimeService.activeAssessmentId == assessment.id;
        final elapsed = live ? studyTimeService.liveElapsed : Duration.zero;
        return SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Study timer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onFullScreen,
                    icon: const Icon(Icons.fullscreen, size: 20),
                    label: const Text('Full screen'),
                  ),
                ],
              ),
              Text(
                formatAssessmentSpentLabel(assessment.spentSeconds),
                style: TextStyle(color: t.textMuted, fontSize: 13),
              ),
              SizedBox(height: t.gap(1.5)),
              LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatElapsedClock(elapsed),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        height: 1,
                        color: t.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: t.gap(2)),
              _StudyTimerStartStop(
                live: live,
                onPressed: () => _toggleAssessmentTimer(
                  context: context,
                  assessment: assessment,
                  studyTimeService: studyTimeService,
                  onSaved: onSaved,
                ),
              ),
              if ((assessment.subjectId ?? '').isEmpty) ...[
                SizedBox(height: t.gap(1)),
                Text(
                  'Pick a subject above so Stop also adds this time on Time.',
                  style: TextStyle(color: t.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FullscreenStudyTimerPage extends StatefulWidget {
  const _FullscreenStudyTimerPage({
    required this.studyTimeService,
    required this.assessmentOf,
    required this.onSaved,
  });

  final StudyTimeService studyTimeService;
  final Assessment Function() assessmentOf;
  final ValueChanged<int> onSaved;

  @override
  State<_FullscreenStudyTimerPage> createState() =>
      _FullscreenStudyTimerPageState();
}

class _FullscreenStudyTimerPageState extends State<_FullscreenStudyTimerPage> {
  static const _zoomPrefsKey = 'assessment_timer_zoomed';
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _loadZoom();
  }

  Future<void> _loadZoom() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _zoomed = prefs.getBool(_zoomPrefsKey) ?? false);
  }

  Future<void> _toggleZoom() async {
    setState(() => _zoomed = !_zoomed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_zoomPrefsKey, _zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.studyTimeService,
          builder: (context, _) {
            final assessment = widget.assessmentOf();
            final live = widget.studyTimeService.isAssessmentLive &&
                widget.studyTimeService.activeAssessmentId == assessment.id;
            final elapsed =
                live ? widget.studyTimeService.liveElapsed : Duration.zero;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                _zoomed ? 12 : 28,
                8,
                _zoomed ? 12 : 28,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Exit full screen',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          assessment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _toggleZoom,
                        icon: Icon(
                          _zoomed ? Icons.zoom_in_map : Icons.zoom_out_map,
                          size: 20,
                        ),
                        label: Text(_zoomed ? 'Zoom out' : 'Zoom'),
                      ),
                    ],
                  ),
                  if (!_zoomed) ...[
                    Text(
                      formatAssessmentSpentLabel(assessment.spentSeconds),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textMuted, fontSize: 14),
                    ),
                    SizedBox(height: t.gap(1)),
                  ],
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          formatElapsedClock(elapsed),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: _zoomed ? 220 : 140,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            height: 1,
                            color: t.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_zoomed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        formatAssessmentSpentLabel(assessment.spentSeconds),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textMuted, fontSize: 13),
                      ),
                    ),
                  _StudyTimerStartStop(
                    live: live,
                    expanded: true,
                    onPressed: () => _toggleAssessmentTimer(
                      context: context,
                      assessment: assessment,
                      studyTimeService: widget.studyTimeService,
                      onSaved: widget.onSaved,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Exit full screen'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudyTimerStartStop extends StatelessWidget {
  const _StudyTimerStartStop({
    required this.live,
    required this.onPressed,
    this.expanded = false,
  });

  final bool live;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
      height: expanded ? 56 : null,
      child: FilledButton(
        onPressed: onPressed,
        style: live
            ? FilledButton.styleFrom(
                backgroundColor: t.urgent,
                foregroundColor: _softStopOn(t.urgent),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(live ? Icons.stop : Icons.play_arrow, size: 22),
            const SizedBox(width: 8),
            Text(live ? 'Stop' : 'Start'),
          ],
        ),
      ),
    );
  }
}

Future<void> _toggleAssessmentTimer({
  required BuildContext context,
  required Assessment assessment,
  required StudyTimeService studyTimeService,
  required ValueChanged<int> onSaved,
}) async {
  final live = studyTimeService.isAssessmentLive &&
      studyTimeService.activeAssessmentId == assessment.id;
  if (live) {
    final hadSubject =
        (studyTimeService.activeSubjectId ?? assessment.subjectId ?? '')
            .isNotEmpty;
    final added = await studyTimeService.stopAssessmentSession();
    onSaved(added);
    if (!hadSubject && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved on this assessment. Pick a subject to also add it on Time.',
          ),
        ),
      );
    }
    return;
  }
  await studyTimeService.startAssessmentSession(
    assessmentId: assessment.id,
    subjectId: assessment.subjectId,
  );
}

Color _softStopOn(Color bg) {
  return bg.computeLuminance() > 0.45
      ? const Color(0xFF2A1612)
      : Colors.white;
}
