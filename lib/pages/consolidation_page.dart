import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/models.dart';
import '../services/consolidation_engine.dart';
import '../services/friction_and_progress.dart';
import '../services/lecture_lab_service.dart';
import '../services/math_format.dart';
import '../services/neural_tts.dart';
import '../services/safe_tts.dart';
import '../services/study_ai_client.dart';
import '../services/study_ai_settings.dart';
import '../services/tts_voice_settings.dart';
import '../theme/design_tokens.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';
import 'voice_chat_page.dart';

enum _Tool {
  quiz,
  flashcards,
  brainDump,
  feynman,
  compare,
  newStory,
  pretest,
  listen,
  voiceTutor,
}

class ConsolidationPage extends StatefulWidget {
  const ConsolidationPage({
    super.key,
    required this.lectureLabService,
    required this.subjects,
    this.progressService,
    this.initialSubjectId,
  });

  final LectureLabService lectureLabService;
  final List<Subject> subjects;
  final ProgressMetricsService? progressService;
  final String? initialSubjectId;

  @override
  State<ConsolidationPage> createState() => _ConsolidationPageState();
}

class _ConsolidationPageState extends State<ConsolidationPage> {
  static const _engine = ConsolidationEngine();
  String? _subjectId;
  _Tool? _tool;
  LectureNote? _scopeLecture;
  var _scopePicked = false;
  var _booting = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
  }

  @override
  void didUpdateWidget(covariant ConsolidationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubjectId != oldWidget.initialSubjectId) {
      _subjectId = widget.initialSubjectId;
    }
  }

  Subject? get _subject {
    if (_subjectId == null) return null;
    for (final s in widget.subjects) {
      if (s.id == _subjectId) return s;
    }
    return null;
  }

  Future<void> _openScope({LectureNote? lecture}) async {
    setState(() {
      _scopeLecture = lecture;
      _scopePicked = true;
      _booting = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _booting = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: StreamBuilder<List<LectureNote>>(
        stream: widget.lectureLabService.streamLectures(),
        builder: (context, lectureSnap) {
          return StreamBuilder<List<ReviewTopic>>(
            stream: widget.lectureLabService.streamTopics(),
            builder: (context, topicSnap) {
              final lectures = _engine.lecturesForSubject(
                lectureSnap.data ?? const [],
                _subject,
              );
              final topics = _engine.topicsForSubject(
                topicSnap.data ?? const [],
                _subject,
              );

              if (_tool != null && !_scopePicked) {
                return _ScopePicker(
                  tool: _tool!,
                  subject: _subject,
                  lectures: lectures,
                  topics: topics,
                  onBack: () => setState(() => _tool = null),
                  onPickAccumulative: () => _openScope(),
                  onPickLecture: (lecture) => _openScope(lecture: lecture),
                );
              }

              if (_tool != null && _booting) {
                return _LoadingPane(
                  onBack: () => setState(() {
                    _booting = false;
                    _scopePicked = false;
                  }),
                );
              }

              if (_tool != null && _scopePicked) {
                final scopedLectures = _scopeLecture == null
                    ? lectures
                    : lectures.where((l) => l.id == _scopeLecture!.id).toList();
                final scopedTopics = _scopeLecture == null
                    ? topics
                    : _engine.topicsForLecture(topics, _scopeLecture!);
                return _SessionHost(
                  tool: _tool!,
                  subject: _subject,
                  lectures: scopedLectures,
                  topics: scopedTopics,
                  service: widget.lectureLabService,
                  progressService: widget.progressService,
                  onClose: () => setState(() {
                    _scopePicked = false;
                    _scopeLecture = null;
                  }),
                );
              }

              return ListView(
                padding: EdgeInsets.all(t.gap(2.5)),
                children: [
                  if (widget.subjects.isEmpty)
                    Text(
                      'Add a subject first, then capture lectures in Lecture Lab.',
                      style: TextStyle(color: t.textMuted),
                    ),
                  SizedBox(height: t.gap(1)),
                  Text(
                    '${lectures.length} lecture(s) · ${topics.length} concept(s)',
                    style: TextStyle(color: t.textMuted, fontSize: 13),
                  ),
                  SizedBox(height: t.gap(2)),
                  _toolCard(
                    context,
                    _Tool.flashcards,
                    'Spaced Flashcards',
                    Icons.style_outlined,
                    recommended: true,
                  ),
                  _toolCard(
                    context,
                    _Tool.quiz,
                    'Consolidation Quiz',
                    Icons.quiz_outlined,
                  ),
                  _toolCard(
                    context,
                    _Tool.listen,
                    'Listen',
                    Icons.headphones_outlined,
                  ),
                  _toolCard(
                    context,
                    _Tool.voiceTutor,
                    'Voice Chat',
                    Icons.graphic_eq,
                  ),
                  _toolCard(
                    context,
                    _Tool.feynman,
                    'Feynman Method',
                    Icons.record_voice_over_outlined,
                  ),
                  _toolCard(
                    context,
                    _Tool.newStory,
                    'Same Engine, New Story',
                    Icons.hub_outlined,
                  ),
                  _toolCard(
                    context,
                    _Tool.brainDump,
                    'Brain Dump',
                    Icons.psychology_outlined,
                  ),
                  _toolCard(
                    context,
                    _Tool.compare,
                    'Compare Two',
                    Icons.compare_arrows,
                  ),
                  _toolCard(
                    context,
                    _Tool.pretest,
                    'Pre-test',
                    Icons.play_circle_outline,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _toolCard(
    BuildContext context,
    _Tool tool,
    String title,
    IconData icon, {
    bool recommended = false,
  }) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.gap(1.25)),
      child: SgCard(
        accent: recommended ? t.primaryAction : null,
        onTap: () => setState(() {
          _tool = tool;
          _scopePicked = false;
          _scopeLecture = null;
        }),
        child: Row(
          children: [
            Icon(icon, size: 36, color: t.primaryAction),
            SizedBox(width: t.gap(1.75)),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (recommended) ...[
              SgStatusTag(label: 'Recommended', color: t.primaryAction),
              SizedBox(width: t.gap(1)),
            ],
            Icon(Icons.chevron_right, size: 28, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  const _ScopePicker({
    required this.tool,
    required this.subject,
    required this.lectures,
    required this.topics,
    required this.onBack,
    required this.onPickAccumulative,
    required this.onPickLecture,
  });

  final _Tool tool;
  final Subject? subject;
  final List<LectureNote> lectures;
  final List<ReviewTopic> topics;
  final VoidCallback onBack;
  final VoidCallback onPickAccumulative;
  final ValueChanged<LectureNote> onPickLecture;

  String get _title => switch (tool) {
        _Tool.quiz => 'Consolidation Quiz',
        _Tool.pretest => 'Pre-test',
        _Tool.flashcards => 'Spaced Flashcards',
        _Tool.brainDump => 'Brain Dump',
        _Tool.feynman => 'Feynman Method',
        _Tool.compare => 'Compare Two',
        _Tool.newStory => 'Same Engine, New Story',
        _Tool.listen => 'Listen',
        _Tool.voiceTutor => 'Voice Chat',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const engine = ConsolidationEngine();
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.gap(1), t.gap(1), t.gap(2), 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(t.gap(2.5)),
            children: [
              Text(
                'Choose a set. Accumulative covers the whole subject. Each lecture is its own section.',
                style: TextStyle(color: t.textMuted, height: 1.4),
              ),
              SizedBox(height: t.gap(2)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPickAccumulative,
                  borderRadius: BorderRadius.circular(t.radiusXl),
                  child: Ink(
                    height: 148,
                    padding: EdgeInsets.all(t.gap(2.5)),
                    decoration: BoxDecoration(
                      color: t.primaryAction.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(t.radiusXl),
                      border: Border.all(
                        color: t.primaryAction.withValues(alpha: 0.45),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCUMULATIVE',
                          style: TextStyle(
                            color: t.primaryAction,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(height: t.gap(0.75)),
                        Text(
                          subject?.label ?? 'Whole subject',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        Text(
                          'All ${lectures.length} lecture(s) Â· ${topics.length} concept(s)',
                          style: TextStyle(color: t.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: t.gap(3)),
              Text('By lecture', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.gap(1)),
              if (lectures.isEmpty)
                Text(
                  'No lectures in this subject yet. Capture one in Lecture Lab, or use accumulative if concepts already exist.',
                  style: TextStyle(color: t.textMuted),
                )
              else
                ...lectures.map((lecture) {
                  final count =
                      engine.topicsForLecture(topics, lecture).length;
                  return Padding(
                    padding: EdgeInsets.only(bottom: t.gap(1)),
                    child: SgCard(
                      onTap: () => onPickLecture(lecture),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: t.primaryAction),
                          SizedBox(width: t.gap(1.5)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MathText(
                                  lecture.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: t.gap(0.35)),
                                Text(
                                  '$count concept(s) Â· tap to open $_title',
                                  style: TextStyle(
                                    color: t.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: t.textMuted),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: t.primaryAction),
                SizedBox(height: t.gap(2)),
                Text(
                  'Loading',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionHost extends StatelessWidget {
  const _SessionHost({
    required this.tool,
    required this.subject,
    required this.lectures,
    required this.topics,
    required this.service,
    required this.onClose,
    this.progressService,
  });

  final _Tool tool;
  final Subject? subject;
  final List<LectureNote> lectures;
  final List<ReviewTopic> topics;
  final LectureLabService service;
  final ProgressMetricsService? progressService;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.gap(1), t.gap(1), t.gap(2), 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  subject?.label ?? 'All subjects',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    switch (tool) {
      case _Tool.quiz:
      case _Tool.pretest:
        return _QuizSession(
          topics: topics,
          lectures: lectures,
          interleaved: false,
          pretest: tool == _Tool.pretest,
          progressService: progressService,
        );
      case _Tool.flashcards:
        return _FlashSession(
          topics: topics,
          service: service,
          progressService: progressService,
        );
      case _Tool.brainDump:
        return _BrainDumpSession(topics: topics, lectures: lectures);
      case _Tool.feynman:
        return _FeynmanSession(topics: topics);
      case _Tool.compare:
        return _CompareSession(topics: topics);
      case _Tool.newStory:
        return _TransferSession(
          topics: topics,
          lectures: lectures,
          progressService: progressService,
        );
      case _Tool.listen:
        return _ListenSession(
          subjectLabel: subject?.label ?? 'this subject',
          lectures: lectures,
          topics: topics,
        );
      case _Tool.voiceTutor:
        return VoiceTutorSession(
          subjectLabel: subject?.label ?? 'this subject',
          lectures: lectures,
          topics: topics,
          progressService: progressService,
        );
    }
  }
}

class _QuizSession extends StatefulWidget {
  const _QuizSession({
    required this.topics,
    required this.lectures,
    required this.interleaved,
    required this.pretest,
    this.progressService,
  });

  final List<ReviewTopic> topics;
  final List<LectureNote> lectures;
  final bool interleaved;
  final bool pretest;
  final ProgressMetricsService? progressService;

  @override
  State<_QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends State<_QuizSession> {
  static const _engine = ConsolidationEngine();
  List<QuizItem> _items = const [];
  var _loading = true;
  String? _loadNote;
  var _index = 0;
  var _correct = 0;
  var _answered = false;
  var _wasRight = false;
  final _shortCtrl = TextEditingController();
  int? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (studyAiSettings.hasKey) {
      try {
        final items = await StudyAiClient.instance.generateQuiz(
          topics: widget.topics,
          lectures: widget.lectures,
          interleaved: widget.interleaved || widget.pretest,
        );
        if (!mounted) return;
        setState(() {
          _items = items;
          _loading = false;
          _loadNote =
              'Generated with Study AI.';
        });
        return;
      } catch (e) {
        _loadNote = 'AI quiz failed ($e). Using local items.';
      }
    }
    final items = _engine.buildQuiz(
      topics: widget.topics,
      lectures: widget.lectures,
      interleaved: widget.interleaved || widget.pretest,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _shortCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) {
      return const _LoadingPane();
    }
    if (_items.isEmpty) {
      return _empty(t, 'Add lecture notes first so there is something to quiz.');
    }
    if (_index >= _items.length) {
      final pct = ((_correct / _items.length) * 100).round();
      return Padding(
        padding: EdgeInsets.all(t.gap(2.5)),
        child: SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: t.gap(1)),
              Text(
                '$_correct / ${_items.length}  Â·  $pct%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: t.gap(1)),
              Text(
                widget.pretest
                    ? 'Pre-test done. Now re-study only the misses — that is the point of generation.'
                    : 'Wrong items showed the lecture excerpt so the correction is sourced, not guessed.',
                style: TextStyle(color: t.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final item = _items[_index];
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text(
          widget.pretest
              ? 'Pre-test ${_index + 1} / ${_items.length}'
              : 'Question ${_index + 1} / ${_items.length}',
          style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700),
        ),
        if (_loadNote != null) ...[
          SizedBox(height: t.gap(0.75)),
          Text(_loadNote!, style: TextStyle(color: t.textMuted, fontSize: 12)),
        ],
        SizedBox(height: t.gap(1.5)),
        MathText(item.prompt, style: Theme.of(context).textTheme.titleMedium),
        if (item.objective != null) ...[
          SizedBox(height: t.gap(1)),
          MathText(
            'Objective: ${item.objective}',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
        ],
        SizedBox(height: t.gap(2)),
        if (item.kind == QuizKind.shortRecall)
          TextField(
            controller: _shortCtrl,
            enabled: !_answered,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your answer',
              alignLabelWithHint: true,
            ),
          )
        else
          ...List.generate(item.options.length, (i) {
            final selected = _picked == i;
            return Padding(
              padding: EdgeInsets.only(bottom: t.gap(1)),
              child: SgCard(
                onTap: _answered
                    ? null
                    : () => setState(() => _picked = i),
                accent: selected ? t.primaryAction.withValues(alpha: 0.5) : null,
                child: MathText(item.options[i]),
              ),
            );
          }),
        SizedBox(height: t.gap(1.5)),
        if (!_answered)
          SgPrimaryButton(
            label: 'Check',
            expanded: true,
            onPressed: _submit,
          )
        else ...[
          SgStatusTag(
            label: _wasRight ? 'Correct' : 'Not yet',
            color: _wasRight ? t.positive : t.warning,
          ),
          SizedBox(height: t.gap(1)),
          MathText(item.explanation, style: TextStyle(color: t.textSecondary, height: 1.45)),
          SizedBox(height: t.gap(2)),
          SgPrimaryButton(
            label: _index + 1 >= _items.length ? 'See score' : 'Next',
            expanded: true,
            onPressed: () {
              setState(() {
                _index++;
                _answered = false;
                _wasRight = false;
                _picked = null;
                _shortCtrl.clear();
              });
            },
          ),
        ],
      ],
    );
  }

  void _submit() {
    final item = _items[_index];
    var right = false;
    if (item.kind == QuizKind.shortRecall) {
      right = _engine.gradeShort(item, _shortCtrl.text);
    } else if (_picked != null && item.correctIndex != null) {
      right = _picked == item.correctIndex;
    }
    setState(() {
      _answered = true;
      _wasRight = right;
      if (right) _correct++;
    });
    widget.progressService?.increment(recalls: 1, strengthened: right ? 1 : 0);
  }
}

class _FlashSession extends StatefulWidget {
  const _FlashSession({
    required this.topics,
    required this.service,
    this.progressService,
  });

  final List<ReviewTopic> topics;
  final LectureLabService service;
  final ProgressMetricsService? progressService;

  @override
  State<_FlashSession> createState() => _FlashSessionState();
}

class _FlashSessionState extends State<_FlashSession>
    with SingleTickerProviderStateMixin {
  static const _engine = ConsolidationEngine();
  late final List<FlashCard> _cards;
  late final AnimationController _flip;
  late final FocusNode _focus;
  var _index = 0;
  var _busy = false;

  bool get _showingBack => _flip.value >= 0.5;

  @override
  void initState() {
    super.initState();
    _cards = _engine.buildFlashcards(widget.topics)..shuffle();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_busy) return;
    if (_flip.isCompleted || _flip.value > 0.5) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  Future<void> _rate(double confidence) async {
    if (_busy || _index >= _cards.length) return;
    if (!_showingBack && _flip.value < 0.5) {
      _flip.forward();
      return;
    }
    _busy = true;
    await widget.service.recordReview(_cards[_index].topicId, confidence);
    await widget.progressService?.increment(
      recalls: 1,
      strengthened: confidence >= 0.7 ? 1 : 0,
    );
    if (!mounted) return;
    _flip.value = 0;
    setState(() {
      _index++;
      _busy = false;
    });
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.space) {
      _toggleFlip();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _rate(0.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _rate(0.85);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_cards.isEmpty) {
      return _empty(t, 'No concepts yet. Extract topics in Lecture Lab.');
    }
    if (_index >= _cards.length) {
      return _empty(t, 'Deck complete. Fading cards will return sooner.');
    }
    final card = _cards[_index];
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.gap(2), t.gap(1.5), t.gap(2), t.gap(2)),
          child: Column(
            children: [
              Text(
                'Card ${_index + 1} / ${_cards.length}',
                style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: t.gap(0.5)),
              Text(
                'Tap the card or press ↑ to flip.  ← don’t know   → know',
                style: TextStyle(color: t.textMuted, fontSize: 13),
              ),
              SizedBox(height: t.gap(1.5)),
              Expanded(
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) {
                    return _PhysicalFlashcard(
                      card: card,
                      animation: _flip,
                      onTap: _toggleFlip,
                    );
                  },
                ),
              ),
              SizedBox(height: t.gap(2)),
              Row(
                children: [
                  Expanded(
                    child: SgSecondaryButton(
                      label: '← Don’t know',
                      onPressed: () => _rate(0.25),
                    ),
                  ),
                  SizedBox(width: t.gap(1.5)),
                  Expanded(
                    child: SgPrimaryButton(
                      label: 'Know →',
                      onPressed: () => _rate(0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhysicalFlashcard extends StatelessWidget {
  const _PhysicalFlashcard({
    required this.card,
    required this.animation,
    required this.onTap,
  });

  final FlashCard card;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = animation.value;
    final showBack = value >= 0.5;
    final angle = value * math.pi;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = Color.lerp(
      t.surfaceElevated,
      const Color(0xFFF4EFE4),
      dark ? 0.08 : 0.55,
    )!;
    final backPaper = Color.lerp(
      t.bgMuted,
      const Color(0xFFEDE4D4),
      dark ? 0.06 : 0.4,
    )!;

    return GestureDetector(
      onTap: onTap,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..rotateY(showBack ? math.pi : 0),
          child: SizedBox.expand(
            child: Container(
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
              decoration: BoxDecoration(
                color: showBack ? backPaper : paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: Offset(showBack ? -10 : 10, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    showBack ? 'ANSWER' : 'PROMPT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.textMuted,
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: MathText(
                          showBack ? card.back : card.front,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                fontSize: 26,
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (!showBack && card.objective != null) ...[
                    const SizedBox(height: 12),
                    MathText(
                      card.objective!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textMuted, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    showBack ? '← don’t know    know →' : 'Tap or ↑ to flip',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrainDumpSession extends StatefulWidget {
  const _BrainDumpSession({required this.topics, required this.lectures});
  final List<ReviewTopic> topics;
  final List<LectureNote> lectures;

  @override
  State<_BrainDumpSession> createState() => _BrainDumpSessionState();
}

class _BrainDumpSessionState extends State<_BrainDumpSession> {
  final _ctrl = TextEditingController();
  var _revealed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titles = widget.topics.map((e) => e.title).toList();
    final written = _ctrl.text.toLowerCase();
    final hit = titles.where((n) => written.contains(n.toLowerCase().split(' ').first)).toList();
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text(
          'Write everything you remember for this subject. Do not look at notes.',
          style: TextStyle(color: t.textSecondary, height: 1.4),
        ),
        SizedBox(height: t.gap(1.5)),
        TextField(
          controller: _ctrl,
          maxLines: 10,
          enabled: !_revealed,
          decoration: const InputDecoration(
            labelText: 'Brain dump',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(2)),
        if (!_revealed)
          SgPrimaryButton(
            label: 'Uncover concepts',
            expanded: true,
            onPressed: () => setState(() => _revealed = true),
          )
        else ...[
          Text(
            'Mentioned ${hit.length} of ${titles.length} concept cues.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: t.gap(1)),
          ...titles.map(
            (n) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                hit.contains(n) ? Icons.check_circle_outline : Icons.circle_outlined,
                color: hit.contains(n) ? t.positive : t.textMuted,
              ),
              title: MathText(n),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeynmanSession extends StatefulWidget {
  const _FeynmanSession({required this.topics});
  final List<ReviewTopic> topics;

  @override
  State<_FeynmanSession> createState() => _FeynmanSessionState();
}

class _FeynmanSessionState extends State<_FeynmanSession> {
  var _index = 0;
  var _revealed = false;
  var _listening = false;
  var _speakingBack = false;
  var _speechReady = false;
  final _ctrl = TextEditingController();
  final _speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    _prepareMic();
  }

  Future<void> _prepareMic() async {
    try {
      _speechReady = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecord() async {
    if (_revealed || _speakingBack) return;
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      final said = _ctrl.text.trim();
      if (said.isEmpty) return;
      setState(() => _speakingBack = true);
      try {
        await SafeTts.instance.speak(text: said);
      } catch (_) {}
      if (mounted) setState(() => _speakingBack = false);
      return;
    }
    if (!_speechReady) {
      await _prepareMic();
    }
    if (!_speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone not available. Allow microphone access, then try Record again.',
          ),
        ),
      );
      return;
    }
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _ctrl.text = result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(minutes: 3),
          pauseFor: const Duration(seconds: 8),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    SafeTts.instance.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (widget.topics.isEmpty) {
      return _empty(t, 'No concepts to teach yet.');
    }
    final topic = widget.topics[_index % widget.topics.length];
    final excerpt = topic.questions
        .map((q) => q.sourceExcerpt)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .firstOrNull;
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        MathText(
          'Teach: ${topic.title}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: t.gap(1)),
        Text(
          'Explain it so a first-year student would follow. No jargon unless you define it.',
          style: TextStyle(color: t.textMuted),
        ),
        SizedBox(height: t.gap(1.5)),
        TextField(
          controller: _ctrl,
          maxLines: 8,
          enabled: !_revealed && !_listening,
          decoration: InputDecoration(
            labelText: _listening
                ? 'Listening… speak your explanation'
                : 'Your explanation',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(1.5)),
        if (!_revealed) ...[
          SgSecondaryButton(
            label: _listening
                ? 'Stop recording'
                : (_speakingBack ? 'Playing back…' : 'Record'),
            icon: _listening ? Icons.stop : Icons.mic_none,
            onPressed: _speakingBack ? null : _toggleRecord,
          ),
          SizedBox(height: t.gap(1)),
          SgPrimaryButton(
            label: 'Compare to notes',
            expanded: true,
            onPressed: (_listening || _speakingBack)
                ? null
                : () => setState(() => _revealed = true),
          ),
        ] else ...[
          Text('Lecture excerpt', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          MathText(
            excerpt ?? 'No excerpt stored — open the lecture and patch the gaps you feel.',
            style: TextStyle(color: t.textSecondary, height: 1.45),
          ),
          SizedBox(height: t.gap(2)),
          SgPrimaryButton(
            label: 'Next concept',
            expanded: true,
            onPressed: () {
              _ctrl.clear();
              _speech.stop();
              SafeTts.instance.stop();
              setState(() {
                _revealed = false;
                _listening = false;
                _speakingBack = false;
                _index++;
              });
            },
          ),
        ],
      ],
    );
  }
}

class _ElaborativeSession extends StatelessWidget {
  const _ElaborativeSession({required this.topics});
  final List<ReviewTopic> topics;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const engine = ConsolidationEngine();
    final prompts = engine.elaborativePrompts(topics);
    if (prompts.isEmpty) return _empty(t, 'Need concepts first.');
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text(
          'Answer each why/how prompt aloud or in writing. The act of generating the reason is the study.',
          style: TextStyle(color: t.textMuted, height: 1.4),
        ),
        SizedBox(height: t.gap(2)),
        ...prompts.map(
          (p) => Padding(
            padding: EdgeInsets.only(bottom: t.gap(1)),
            child: SgCard(child: MathText(p)),
          ),
        ),
      ],
    );
  }
}

class _CompareSession extends StatelessWidget {
  const _CompareSession({required this.topics});
  final List<ReviewTopic> topics;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const engine = ConsolidationEngine();
    final pairs = engine.comparisons(topics);
    if (pairs.isEmpty) {
      return _empty(t, 'Need at least two concepts in this subject.');
    }
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: pairs
          .map(
            (p) => Padding(
              padding: EdgeInsets.only(bottom: t.gap(1.25)),
              child: SgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathText(p.prompt, style: const TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: t.gap(1)),
                    TextField(
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Your contrast',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KnobSession extends StatefulWidget {
  const _KnobSession({
    required this.topics,
    required this.lectures,
    this.progressService,
  });

  final List<ReviewTopic> topics;
  final List<LectureNote> lectures;
  final ProgressMetricsService? progressService;

  @override
  State<_KnobSession> createState() => _KnobSessionState();
}

class _KnobSessionState extends State<_KnobSession> {
  static const _engine = ConsolidationEngine();
  List<KnobItem> _items = const [];
  var _loading = true;
  String? _loadNote;
  var _index = 0;
  var _revealed = false;
  final _holdsCtrl = TextEditingController();
  final _collapsesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = _engine.buildKnobItems(widget.topics, widget.lectures);
    if (local.isNotEmpty && mounted) {
      setState(() {
        _items = local;
        _loading = false;
      });
    }
    if (studyAiSettings.hasKey) {
      try {
        final items = await StudyAiClient.instance
            .generateKnobItems(
              topics: widget.topics,
              lectures: widget.lectures,
            )
            .timeout(const Duration(seconds: 25));
        if (!mounted) return;
        if (!_revealed && _index == 0 && _holdsCtrl.text.isEmpty) {
          setState(() {
            _items = items;
            _loading = false;
            _loadNote =
                'Generated with Study AI.';
          });
        }
        return;
      } catch (e) {
        _loadNote = 'AI knobs failed ($e). Using local items.';
      }
    }
    if (!mounted) return;
    setState(() {
      _items = local;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _holdsCtrl.dispose();
    _collapsesCtrl.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _revealed = true);
    widget.progressService?.increment(recalls: 1);
  }

  void _next() {
    _holdsCtrl.clear();
    _collapsesCtrl.clear();
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) return const _LoadingPane();
    if (_items.isEmpty) {
      return _empty(t, 'Add lecture notes first so there is a condition to flip.');
    }
    if (_index >= _items.length) {
      return Padding(
        padding: EdgeInsets.all(t.gap(2.5)),
        child: SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Done', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: t.gap(1)),
              Text(
                '${_items.length} knob(s). The work was saying when the idea stops applying, not restating the definition.',
                style: TextStyle(color: t.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final item = _items[_index];
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text(
          'Knob ${_index + 1} / ${_items.length}',
          style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700),
        ),
        if (_loadNote != null) ...[
          SizedBox(height: t.gap(0.75)),
          Text(_loadNote!, style: TextStyle(color: t.textMuted, fontSize: 12)),
        ],
        SizedBox(height: t.gap(1.5)),
        MathText(
          item.topicTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (item.objective != null) ...[
          SizedBox(height: t.gap(0.75)),
          MathText(
            'Objective: ${item.objective}',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
        ],
        SizedBox(height: t.gap(1.5)),
        Text(
          'Change one condition. Write what still holds and what collapses. Do not look at the notes yet.',
          style: TextStyle(color: t.textMuted, height: 1.4),
        ),
        SizedBox(height: t.gap(1.5)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE KNOB',
                style: TextStyle(
                  color: t.primaryAction,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: t.gap(0.75)),
              MathText(
                item.changedCondition,
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
              ),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        TextField(
          controller: _holdsCtrl,
          enabled: !_revealed,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What still holds',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(1.5)),
        TextField(
          controller: _collapsesCtrl,
          enabled: !_revealed,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What collapses',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(2)),
        if (!_revealed)
          SgPrimaryButton(
            label: 'Compare to notes',
            expanded: true,
            onPressed: _reveal,
          )
        else ...[
          Text('As the notes treat it', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          MathText(item.mechanism, style: TextStyle(color: t.textSecondary, height: 1.45)),
          SizedBox(height: t.gap(1.5)),
          Text('Still holds', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          MathText(item.stillHolds, style: TextStyle(color: t.textSecondary, height: 1.45)),
          SizedBox(height: t.gap(1.5)),
          Text('Collapses', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          MathText(item.collapses, style: TextStyle(color: t.textSecondary, height: 1.45)),
          if (item.sourceExcerpt != null && item.sourceExcerpt!.trim().isNotEmpty) ...[
            SizedBox(height: t.gap(1.5)),
            Text('Lecture excerpt', style: const TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: t.gap(0.75)),
            MathText(
              item.sourceExcerpt!,
              style: TextStyle(color: t.textSecondary, height: 1.45),
            ),
          ],
          SizedBox(height: t.gap(2)),
          SgPrimaryButton(
            label: _index + 1 >= _items.length ? 'Finish' : 'Next knob',
            expanded: true,
            onPressed: _next,
          ),
        ],
      ],
    );
  }
}

class _TransferSession extends StatefulWidget {
  const _TransferSession({
    required this.topics,
    required this.lectures,
    this.progressService,
  });

  final List<ReviewTopic> topics;
  final List<LectureNote> lectures;
  final ProgressMetricsService? progressService;

  @override
  State<_TransferSession> createState() => _TransferSessionState();
}

class _TransferSessionState extends State<_TransferSession> {
  static const _engine = ConsolidationEngine();
  List<TransferItem> _items = const [];
  var _loading = true;
  String? _loadNote;
  var _index = 0;
  var _revealed = false;
  final _mapCtrl = TextEditingController();
  final _refuseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = _engine.buildTransferItems(widget.topics, widget.lectures);
    if (local.isNotEmpty && mounted) {
      setState(() {
        _items = local;
        _loading = false;
      });
    }
    if (studyAiSettings.hasKey) {
      try {
        final items = await StudyAiClient.instance
            .generateTransferItems(
              topics: widget.topics,
              lectures: widget.lectures,
            )
            .timeout(const Duration(seconds: 25));
        if (!mounted) return;
        if (!_revealed && _index == 0 && _mapCtrl.text.isEmpty) {
          setState(() {
            _items = items;
            _loading = false;
            _loadNote =
                'Generated with Study AI.';
          });
        }
        return;
      } catch (e) {
        _loadNote = 'AI stories failed ($e). Using local items.';
      }
    }
    if (!mounted) return;
    setState(() {
      _items = local;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _refuseCtrl.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _revealed = true);
    widget.progressService?.increment(recalls: 1);
  }

  void _next() {
    _mapCtrl.clear();
    _refuseCtrl.clear();
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) return const _LoadingPane();
    if (_items.isEmpty) {
      return _empty(t, 'Add lecture notes first so there is a structure to move.');
    }
    if (_index >= _items.length) {
      return Padding(
        padding: EdgeInsets.all(t.gap(2.5)),
        child: SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Done', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: t.gap(1)),
              Text(
                '${_items.length} story(ies). Transfer is knowing which parts correspond — and which must not.',
                style: TextStyle(color: t.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final item = _items[_index];
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text(
          'Story ${_index + 1} / ${_items.length}',
          style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700),
        ),
        if (_loadNote != null) ...[
          SizedBox(height: t.gap(0.75)),
          Text(_loadNote!, style: TextStyle(color: t.textMuted, fontSize: 12)),
        ],
        SizedBox(height: t.gap(1.5)),
        MathText(
          item.topicTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (item.objective != null) ...[
          SizedBox(height: t.gap(0.75)),
          MathText(
            'Objective: ${item.objective}',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
        ],
        SizedBox(height: t.gap(1.5)),
        Text(
          'Same deep structure, new surface. Map the parts that correspond. Name the tempting maps that are false.',
          style: TextStyle(color: t.textMuted, height: 1.4),
        ),
        SizedBox(height: t.gap(1.5)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LECTURE SITUATION',
                style: TextStyle(
                  color: t.primaryAction,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: t.gap(0.75)),
              MathText(item.originalSituation, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
        SizedBox(height: t.gap(1)),
        SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEW STORY',
                style: TextStyle(
                  color: t.primaryAction,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: t.gap(0.75)),
              MathText(
                item.newStory,
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
              ),
            ],
          ),
        ),
        SizedBox(height: t.gap(2)),
        TextField(
          controller: _mapCtrl,
          enabled: !_revealed,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What maps onto what',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(1.5)),
        TextField(
          controller: _refuseCtrl,
          enabled: !_revealed,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What must not be mapped',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(2)),
        if (!_revealed)
          SgPrimaryButton(
            label: 'Compare to notes',
            expanded: true,
            onPressed: _reveal,
          )
        else ...[
          Text('Correspondences', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          if (item.correspondences.isEmpty)
            Text(
              'No stored mapping — check the excerpt and keep only structural matches.',
              style: TextStyle(color: t.textSecondary, height: 1.45),
            )
          else
            ...item.correspondences.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: t.gap(0.75)),
                child: MathText(
                  line,
                  style: TextStyle(color: t.textSecondary, height: 1.45),
                ),
              ),
            ),
          SizedBox(height: t.gap(1.5)),
          Text('Do not map', style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: t.gap(0.75)),
          if (item.doNotMap.isEmpty)
            Text(
              'Refuse any extra cause or surface detail the lectures never treat as part of the mechanism.',
              style: TextStyle(color: t.textSecondary, height: 1.45),
            )
          else
            ...item.doNotMap.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: t.gap(0.75)),
                child: MathText(
                  line,
                  style: TextStyle(color: t.textSecondary, height: 1.45),
                ),
              ),
            ),
          if (item.sourceExcerpt != null && item.sourceExcerpt!.trim().isNotEmpty) ...[
            SizedBox(height: t.gap(1.5)),
            Text('Lecture excerpt', style: const TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: t.gap(0.75)),
            MathText(
              item.sourceExcerpt!,
              style: TextStyle(color: t.textSecondary, height: 1.45),
            ),
          ],
          SizedBox(height: t.gap(2)),
          SgPrimaryButton(
            label: _index + 1 >= _items.length ? 'Finish' : 'Next story',
            expanded: true,
            onPressed: _next,
          ),
        ],
      ],
    );
  }
}

class _CoverRecallSession extends StatefulWidget {
  const _CoverRecallSession({required this.lectures, required this.topics});
  final List<LectureNote> lectures;
  final List<ReviewTopic> topics;

  @override
  State<_CoverRecallSession> createState() => _CoverRecallSessionState();
}

class _CoverRecallSessionState extends State<_CoverRecallSession> {
  var _show = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (widget.lectures.isEmpty) {
      return _empty(t, 'Paste a lecture in Lecture Lab first.');
    }
    final lecture = widget.lectures.first;
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        MathText(lecture.title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: t.gap(1)),
        if (!_show)
          SgCard(
            child: Text(
              'Notes are covered. Write the structure and key claims, then uncover.',
              style: TextStyle(color: t.textMuted),
            ),
          )
        else
          SgCard(
            child: MathText(lecture.body, style: const TextStyle(height: 1.45)),
          ),
        SizedBox(height: t.gap(1.5)),
        TextField(
          controller: _ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'What you remember',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: t.gap(2)),
        SgPrimaryButton(
          label: _show ? 'Cover again' : 'Uncover notes',
          expanded: true,
          onPressed: () => setState(() => _show = !_show),
        ),
      ],
    );
  }
}

class _ListenSession extends StatefulWidget {
  const _ListenSession({
    required this.subjectLabel,
    required this.lectures,
    required this.topics,
  });

  final String subjectLabel;
  final List<LectureNote> lectures;
  final List<ReviewTopic> topics;

  @override
  State<_ListenSession> createState() => _ListenSessionState();
}

class _ListenSessionState extends State<_ListenSession> {
  ListenVibe _vibe = ListenVibe.calmCoach;
  var _playing = false;
  var _sampling = false;
  var _preparing = false;
  var _aiBusy = false;
  var _usedAi = false;
  String? _sampleId;
  NeuralVoice _selected = NeuralVoice.nova;
  late String _script;

  @override
  void initState() {
    super.initState();
    _rebuild();
    _prepareVoice();
    if (studyAiSettings.hasKey) {
      _generateAi();
    }
  }

  Future<void> _prepareVoice() async {
    await ttsVoiceSettings.load();
    if (!mounted) return;
    setState(() {
      _selected = NeuralVoice.byId(ttsVoiceSettings.name);
    });
  }

  void _rebuild() {
    _script = const ConsolidationEngine().listenScript(
      vibe: _vibe,
      subjectLabel: widget.subjectLabel,
      lectures: widget.lectures,
      topics: widget.topics,
    );
    _usedAi = false;
  }

  Future<void> _generateAi() async {
    if (!studyAiSettings.hasKey) return;
    setState(() => _aiBusy = true);
    try {
      final script = await StudyAiClient.instance.generateListenScript(
        vibe: _vibe,
        subjectLabel: widget.subjectLabel,
        lectures: widget.lectures,
        topics: widget.topics,
      );
      if (!mounted) return;
      setState(() {
        _script = script;
        _usedAi = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI script failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  void dispose() {
    NeuralTts.instance.stop();
    super.dispose();
  }

  Future<void> _applyVoice(NeuralVoice voice) async {
    await ttsVoiceSettings.save(
      TtsVoiceChoice(name: voice.id, locale: 'en'),
    );
    if (mounted) setState(() => _selected = voice);
  }

  Future<void> _playSample(NeuralVoice voice) async {
    if (!studyAiSettings.hasOpenAiSpeech) {
      _needKey();
      return;
    }
    setState(() {
      _sampling = true;
      _sampleId = voice.id;
      _playing = false;
    });
    try {
      await NeuralTts.instance.playSample(voice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _sampling = false;
        _sampleId = null;
      });
    }
  }

  Future<void> _play() async {
    if (!studyAiSettings.hasOpenAiSpeech) {
      _needKey();
      return;
    }
    setState(() {
      _playing = true;
      _preparing = true;
    });
    try {
      final future = NeuralTts.instance.speak(
        text: MathFormat.forSpeech(_script),
        voice: _selected,
        vibe: _vibe,
        onStarted: () {
          if (mounted) setState(() => _preparing = false);
        },
      );
      await future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _playing = false;
        _preparing = false;
      });
    }
  }

  void _needKey() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Natural Listen voices need an OpenAI key. Add one under Listen voices in Settings.',
        ),
      ),
    );
  }

  Future<void> _stop() async {
    await NeuralTts.instance.stop();
    if (!mounted) return;
    setState(() {
      _playing = false;
      _sampling = false;
      _preparing = false;
      _sampleId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: EdgeInsets.all(t.gap(2.5)),
      children: [
        Text('Voice', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: t.gap(0.5)),
        Text(
          studyAiSettings.hasOpenAiSpeech
              ? 'OpenAI neural voices. Play a sample, then choose one.'
              : 'Add an OpenAI key in Settings → Listen voices to unlock these.',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        SizedBox(height: t.gap(1.5)),
        ...NeuralVoice.all.map(_voiceTile),
        SizedBox(height: t.gap(3)),
        Text('Vibe', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: t.gap(1)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ListenVibe.values.map((v) {
            return FilterChip(
              label: Text(v.label),
              selected: _vibe == v,
              onSelected: (_) {
                NeuralTts.instance.stop();
                setState(() {
                  _vibe = v;
                  _playing = false;
                  _rebuild();
                });
                if (studyAiSettings.hasKey) _generateAi();
              },
            );
          }).toList(),
        ),
        SizedBox(height: t.gap(0.75)),
        Text(
          _aiBusy
              ? 'Writing script with your ${studyAiSettings.provider.label} key…'
              : (_usedAi ? 'AI script Â· ${_vibe.hint}' : _vibe.hint),
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        SizedBox(height: t.gap(2)),
        SgPrimaryButton(
          label: _preparing
              ? 'Preparing voice…'
              : (_playing ? 'Playing…' : 'Play notes'),
          icon: Icons.play_arrow_rounded,
          expanded: true,
          onPressed: (_playing || _aiBusy || _sampling) ? null : _play,
        ),
        SizedBox(height: t.gap(1)),
        SgSecondaryButton(
          label: 'Stop',
          icon: Icons.stop,
          onPressed: _stop,
        ),
        SizedBox(height: t.gap(2)),
        MathText(_script, style: TextStyle(color: t.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _voiceTile(NeuralVoice voice) {
    final t = context.tokens;
    final selected = _selected.id == voice.id;
    final samplingThis = _sampleId == voice.id;
    final recommended = voice.id == NeuralVoice.nova.id;
    return Padding(
      padding: EdgeInsets.only(bottom: t.gap(1)),
      child: SgCard(
        onTap: () => _applyVoice(voice),
        accent: selected ? t.primaryAction.withValues(alpha: 0.5) : null,
        child: Row(
          children: [
            Icon(
              selected ? Icons.graphic_eq : Icons.record_voice_over_outlined,
              color: selected ? t.primaryAction : t.textMuted,
            ),
            SizedBox(width: t.gap(1.5)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    [
                      voice.hint,
                      if (recommended) 'recommended',
                      if (selected) 'selected',
                    ].join(' Â· '),
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            SgSecondaryButton(
              label: samplingThis ? 'Playing…' : 'Sample',
              icon: Icons.volume_up_outlined,
              onPressed: (_sampling && !samplingThis)
                  ? null
                  : () => samplingThis ? _stop() : _playSample(voice),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _empty(DesignTokens t, String body) {
  return Padding(
    padding: EdgeInsets.all(t.gap(2.5)),
    child: SgEmptyState(title: 'Nothing to practise yet', body: body),
  );
}
