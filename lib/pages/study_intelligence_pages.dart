import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/friction_and_progress.dart';
import '../services/gap_engine.dart';
import '../services/lecture_file_import.dart';
import '../services/lecture_lab_service.dart';
import '../services/study_ai_settings.dart';
import '../services/memory_weather_engine.dart';
import '../services/readiness_engine.dart';
import '../theme/design_tokens.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';

class MemoryWeatherPage extends StatelessWidget {
  const MemoryWeatherPage({
    super.key,
    required this.lectureLabService,
    required this.assessments,
    this.frictionService,
    this.progressService,
    this.onOpenAssessment,
  });

  final LectureLabService lectureLabService;
  final List<Assessment> assessments;
  final FrictionService? frictionService;
  final ProgressMetricsService? progressService;
  final void Function(Assessment)? onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final engine = const MemoryWeatherEngine();

    return SafeArea(
      child: StreamBuilder<List<ReviewTopic>>(
        stream: lectureLabService.streamTopics(),
        builder: (context, snap) {
          final topics = snap.data ?? const <ReviewTopic>[];
          final insight = engine.evaluate(topics: topics);
          final related = assessments
              .where((a) => insight.relatedAssessmentIds.contains(a.id))
              .toList();

          return ListView(
            padding: EdgeInsets.all(t.gap(2.5)),
            children: [
              SgSectionHeader(
                eyebrow: 'Memory weather',
                title: insight.headline,
                subtitle: insight.reason,
              ),
              SizedBox(height: t.gap(2)),
              SgCard(
                accent: _weatherAccent(t, insight.state),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SgStatusTag(
                      label: insight.state.label,
                      color: _weatherAccent(t, insight.state),
                      icon: Icons.cloud_outlined,
                    ),
                    SizedBox(height: t.gap(1.5)),
                    Text(
                      insight.nextReviewLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: t.gap(1)),
                    Text(
                      'Smallest recovery: ~${insight.smallestRecoveryMinutes} min',
                      style: TextStyle(color: t.textMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.gap(2)),
              Text('Fading concepts',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.gap(1)),
              if (insight.fadingTopics.isEmpty)
                Text('None flagged right now.',
                    style: TextStyle(color: t.textMuted))
              else
                ...insight.fadingTopics.map(
                  (topic) => Padding(
                    padding: EdgeInsets.only(bottom: t.gap(1)),
                    child: SgCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MathText(topic.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          if (topic.course != null)
                            Text(topic.course!,
                                style: TextStyle(color: t.textMuted)),
                          SizedBox(height: t.gap(1)),
                          SgSecondaryButton(
                            label: 'Mark reviewed',
                            onPressed: () async {
                              await lectureLabService.recordReview(
                                topic.id,
                                topic.confidence ?? 0.55,
                              );
                              await progressService?.increment(
                                recalls: 1,
                                strengthened: 1,
                              );
                              if (context.mounted) {
                                announceForAccessibility(
                                  context,
                                  'Recorded review for ${topic.title}',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (related.isNotEmpty) ...[
                SizedBox(height: t.gap(2)),
                Text('Related assessments',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: t.gap(1)),
                ...related.map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.title),
                    subtitle: Text(a.dueLabel),
                    onTap: onOpenAssessment == null
                        ? null
                        : () => onOpenAssessment!(a),
                  ),
                ),
              ],
              SizedBox(height: t.gap(2)),
              ExpansionTile(
                title: const Text('Why this reading?'),
                children: insight.inspectableSteps
                    .map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s, style: TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _weatherAccent(DesignTokens t, MemoryWeatherState s) => switch (s) {
        MemoryWeatherState.clear => t.positive,
        MemoryWeatherState.clouding => t.warning,
        MemoryWeatherState.fog => t.urgent,
        MemoryWeatherState.recoveryUnderway => t.secondaryAccent,
      };
}

class LectureLabPage extends StatefulWidget {
  const LectureLabPage({
    super.key,
    required this.service,
    this.subjects = const [],
    this.assessments = const [],
  });

  final LectureLabService service;
  final List<Subject> subjects;
  final List<Assessment> assessments;

  @override
  State<LectureLabPage> createState() => _LectureLabPageState();
}

class _AttachedLecture {
  const _AttachedLecture({
    required this.filename,
    this.bytes,
    this.mediaType,
  });

  final String filename;
  final Uint8List? bytes;
  final String? mediaType;

  bool get isPdf => mediaType == 'application/pdf' && bytes != null;
}

class _LectureLabPageState extends State<LectureLabPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _objectivesCtrl = TextEditingController();
  String? _subjectId;
  String? _linkAssessmentId;
  bool _saving = false;
  bool _importing = false;
  bool _dragging = false;
  final _attached = <_AttachedLecture>[];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _objectivesCtrl.dispose();
    super.dispose();
  }

  List<String> _parseObjectives() {
    return _objectivesCtrl.text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Subject? get _subject {
    if (_subjectId == null) return null;
    for (final s in widget.subjects) {
      if (s.id == _subjectId) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(t.gap(2.5)),
        children: [
          SgSectionHeader(
            eyebrow: 'Lecture lab',
            title: 'From notes to recall',
            subtitle: widget.service.supportsAi
                ? 'Using your ${studyAiSettings.provider.label} key to extract concepts.'
                : 'Add an API key in Settings to extract with AI. Until then, headings and bullets are used.',
          ),
          SizedBox(height: t.gap(2)),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Lecture title'),
          ),
          SizedBox(height: t.gap(1)),
          DropdownButtonFormField<String?>(
            value: _subjectId,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No subject')),
              ...widget.subjects.map(
                (s) => DropdownMenuItem(value: s.id, child: Text(s.label)),
              ),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          SizedBox(height: t.gap(1)),
          if (widget.assessments.isNotEmpty)
            DropdownButtonFormField<String?>(
              value: _linkAssessmentId,
              decoration: const InputDecoration(labelText: 'Link assessment'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...widget.assessments.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.title)),
                ),
              ],
              onChanged: (v) => setState(() => _linkAssessmentId = v),
            ),
          SizedBox(height: t.gap(1)),
          TextField(
            controller: _objectivesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Learning objectives (one per line, optional)',
              hintText: 'e.g. Explain the difference between X and Y',
              alignLabelWithHint: true,
            ),
          ),
          SizedBox(height: t.gap(1)),
          DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) async {
              setState(() => _dragging = false);
              await _importPaths(
                details.files
                    .map((f) => f.path)
                    .whereType<String>()
                    .where((p) => p.trim().isNotEmpty)
                    .toList(),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusMd),
                border: Border.all(
                  color: _dragging
                      ? t.primaryAction
                      : t.border.withValues(alpha: 0.35),
                  width: _dragging ? 2 : 1,
                ),
                color: _dragging
                    ? t.primaryAction.withValues(alpha: 0.08)
                    : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Paste notes (optional if you add a PDF)',
                      hintText:
                          'Type or paste notes. PDFs stay attached — they are not dumped here.',
                      alignLabelWithHint: true,
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SgSecondaryButton(
                        label: _importing ? 'Reading file…' : 'Add file',
                        icon: Icons.attach_file,
                        onPressed: _importing ? null : _pickFiles,
                      ),
                      Text(
                        'PDF · Word · PowerPoint · text · images',
                        style: TextStyle(color: t.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  if (_attached.isNotEmpty) ...[
                    SizedBox(height: t.gap(1)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attached
                          .map(
                            (file) => Chip(
                              avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
                              label: Text(file.filename),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: t.gap(2)),
          SgPrimaryButton(
            label: _saving
                ? (widget.service.supportsAi ? 'Extracting with AI…' : 'Saving…')
                : (widget.service.supportsAi
                    ? 'Extract with AI'
                    : 'Extract topics & questions'),
            expanded: true,
            onPressed: (_saving || _importing) ? null : _save,
          ),
          SizedBox(height: t.gap(3)),
          Text('Saved lectures', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: t.gap(1)),
          StreamBuilder<List<LectureNote>>(
            stream: widget.service.streamLectures(),
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Text('None yet.', style: TextStyle(color: t.textMuted));
              }
              return Column(
                children: list
                    .map(
                      (l) => Padding(
                        padding: EdgeInsets.only(bottom: t.gap(1)),
                        child: SgCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: MathText(l.title),
                            subtitle: Text(
                              [
                                l.course ?? 'No subject',
                                '${l.topicIds.length} topics',
                                if (l.learningObjectives.isNotEmpty)
                                  '${l.learningObjectives.length} objectives',
                              ].join(' · '),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: LectureFileImport.allowedExtensions,
      withData: true,
    );
    if (picked == null) return;
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await _ingest(filename: f.name, bytes: bytes);
      } else if (f.path != null) {
        await _importPaths([f.path!]);
      }
    }
  }

  Future<void> _importPaths(List<String> paths) async {
    setState(() => _importing = true);
    try {
      for (final path in paths) {
        try {
          final result = await const LectureFileImport().importPath(path);
          if (!mounted) return;
          _applyImport(result);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _ingest({
    required String filename,
    required List<int> bytes,
  }) async {
    setState(() => _importing = true);
    try {
      final result = await const LectureFileImport().importBytes(
        filename: filename,
        bytes: Uint8List.fromList(bytes),
      );
      _applyImport(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _applyImport(LectureImportResult result) {
    if (_titleCtrl.text.trim().isEmpty) {
      final name = result.filename.replaceAll(RegExp(r'\.[^.]+$'), '');
      _titleCtrl.text = name;
    }
    if (result.isPdf) {
      setState(() {
        if (!_attached.any((f) => f.filename == result.filename)) {
          _attached.add(
            _AttachedLecture(
              filename: result.filename,
              bytes: result.bytes,
              mediaType: result.mediaType,
            ),
          );
        }
      });
      return;
    }
    if (result.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No text found in ${result.filename}.')),
      );
      return;
    }
    final chunk = '--- ${result.filename} ---\n${result.text.trim()}';
    final existing = _bodyCtrl.text.trim();
    _bodyCtrl.text = existing.isEmpty ? chunk : '$existing\n\n$chunk';
    setState(() {
      if (!_attached.any((f) => f.filename == result.filename)) {
        _attached.add(_AttachedLecture(filename: result.filename));
      }
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final notes = _bodyCtrl.text.trim();
    final pdf = _attached.where((f) => f.isPdf).firstOrNull;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a lecture title.')),
      );
      return;
    }
    if (notes.isEmpty && pdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste notes or add a PDF, then extract.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final subject = _subject;
      final objectives = _parseObjectives();
      await widget.service.saveLecture(
        title: title,
        body: notes,
        course: subject?.label,
        subjectId: subject?.id,
        assessmentIds:
            _linkAssessmentId == null ? const [] : [_linkAssessmentId!],
        lectureDate: DateTime.now(),
        learningObjectives: objectives,
        pdfBytes: pdf?.bytes,
        pdfFilename: pdf?.filename,
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _objectivesCtrl.clear();
      _attached.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.service.supportsAi
                  ? (objectives.isEmpty
                      ? (pdf != null
                          ? 'AI extracted topics from the PDF'
                          : 'AI extracted topics from your notes')
                      : 'AI aligned topics to learning objectives')
                  : (objectives.isEmpty
                      ? 'Topics and recall questions created from notes'
                      : 'Topics aligned to learning objectives'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class GapSessionCard extends StatelessWidget {
  const GapSessionCard({
    super.key,
    required this.events,
    required this.assessments,
    required this.topics,
    this.friction,
    this.frictionService,
    this.progressService,
    this.onBeginReview,
    this.onBeginConsolidation,
  });

  final List<AppEvent> events;
  final List<Assessment> assessments;
  final List<ReviewTopic> topics;
  final FrictionReason? friction;
  final FrictionService? frictionService;
  final ProgressMetricsService? progressService;
  final VoidCallback? onBeginReview;
  final VoidCallback? onBeginConsolidation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final engine = const CalendarGapEngine();
    final weather = const MemoryWeatherEngine();
    final now = DateTime.now();
    final start = now.hour * 60 + now.minute;
    final gaps = engine.detectGaps(
      events: events,
      dayStartMinutes: start,
      dayEndMinutes: 22 * 60,
      recentFriction: friction,
    );
    final mode =
        frictionService?.preferredMode(friction) ?? StudyContextMode.balanced;
    final session = engine.recommendSession(
      gaps: gaps,
      assessments: assessments,
      topics: topics,
      mode: mode,
      recentFriction: friction,
    );
    final fading = weather.evaluate(topics: topics).fadingTopics.isNotEmpty;
    final beginReview = fading || session?.topicId != null;
    final label = beginReview ? 'Begin Review' : 'Begin Consolidation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GAP SESSION',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          session == null
              ? 'Whenever you are ready'
              : '${session.durationMinutes} min free',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        const Spacer(),
        SgPrimaryButton(
          label: label,
          icon: Icons.play_arrow_rounded,
          expanded: true,
          onPressed: () {
            progressService?.increment(
              gapSessions: session == null ? 0 : 1,
              accepted: 1,
              minutes: session?.durationMinutes ?? 0,
            );
            if (beginReview) {
              onBeginReview?.call();
            } else {
              onBeginConsolidation?.call();
            }
          },
        ),
      ],
    );
  }
}

/// Small readiness strip for dashboard using real assessment data.
class DashboardReadinessStrip extends StatelessWidget {
  const DashboardReadinessStrip({
    super.key,
    required this.assessments,
    required this.onOpen,
  });

  final List<Assessment> assessments;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final engine = const AssessmentReadinessEngine();
    final hero = engine.mostImportant(assessments);
    final t = context.tokens;
    if (hero == null) {
      return SgCard(
        onTap: onOpen,
        child: Text(
          'No assessments yet — add one to unlock readiness planning.',
          style: TextStyle(color: t.textMuted),
        ),
      );
    }
    final e = engine.explain(hero);
    return SgCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next pressure',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: t.textMuted,
              )),
          SizedBox(height: t.gap(0.75)),
          Text(hero.title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${e.state.calmLabel} · ${hero.dueLabel}',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
