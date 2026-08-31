import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/consolidation_engine.dart';
import '../services/friction_and_progress.dart';
import '../services/lecture_lab_service.dart';
import '../services/neural_tts.dart';
import '../services/realtime_tutor.dart';
import '../services/tts_voice_settings.dart';
import '../theme/design_tokens.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';
import '../ui/voice_orb.dart';

class VoiceChatPage extends StatefulWidget {
  const VoiceChatPage({
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
  State<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage> {
  static const _engine = ConsolidationEngine();
  String? _subjectId;
  String? _lectureId;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
  }

  @override
  void didUpdateWidget(covariant VoiceChatPage oldWidget) {
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
              final lecture = lectures
                  .where((l) => l.id == _lectureId)
                  .firstOrNull;
              final scopedLectures =
                  lecture == null ? lectures : <LectureNote>[lecture];
              final scopedTopics = lecture == null
                  ? topics
                  : _engine.topicsForLecture(topics, lecture);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.gap(2.5),
                      t.gap(1.5),
                      t.gap(2.5),
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.subjects.isEmpty)
                          Text(
                            'Add a subject, then capture lectures in Lecture Lab.',
                            style: TextStyle(color: t.textMuted, height: 1.4),
                          ),
                        if (lectures.isNotEmpty) ...[
                          SizedBox(height: t.gap(1)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('All lectures'),
                                selected: _lectureId == null,
                                onSelected: (_) =>
                                    setState(() => _lectureId = null),
                              ),
                              ...lectures.map((l) {
                                return FilterChip(
                                  label: Text(
                                    l.title.trim().isEmpty
                                        ? 'Untitled lecture'
                                        : l.title,
                                  ),
                                  selected: _lectureId == l.id,
                                  onSelected: (_) =>
                                      setState(() => _lectureId = l.id),
                                );
                              }),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: VoiceTutorSession(
                      key: ValueKey(
                        '${_subjectId ?? 'none'}-${_lectureId ?? 'all'}',
                      ),
                      subjectLabel: _subject?.label ?? 'this subject',
                      lectures: scopedLectures,
                      topics: scopedTopics,
                      progressService: widget.progressService,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class VoiceTutorSession extends StatefulWidget {
  const VoiceTutorSession({
    super.key,
    required this.subjectLabel,
    required this.lectures,
    required this.topics,
    this.progressService,
  });

  final String subjectLabel;
  final List<LectureNote> lectures;
  final List<ReviewTopic> topics;
  final ProgressMetricsService? progressService;

  @override
  State<VoiceTutorSession> createState() => _VoiceTutorSessionState();
}

class _VoiceTutorSessionState extends State<VoiceTutorSession> {
  final _tutor = RealtimeTutor();
  final _lines = <RealtimeLine>[];
  final _level = ValueNotifier<double>(0);
  final _ask = TextEditingController();
  var _phase = RealtimePhase.connecting;
  var _muted = false;
  var _showTranscript = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tutor.onPhase = (phase) {
      if (!mounted) return;
      setState(() => _phase = phase);
    };
    _tutor.onLine = (line) {
      if (!mounted) return;
      setState(() => _lines.add(line));
    };
    _tutor.onError = (message) {
      if (!mounted) return;
      setState(() => _error = message);
    };
    _tutor.onLevel = (value) {
      _level.value = value;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connect();
    });
  }

  Future<void> _connect() async {
    setState(() {
      _error = null;
      _phase = RealtimePhase.connecting;
    });
    try {
      await ttsVoiceSettings.load();
      final briefing = const ConsolidationEngine().tutorBriefing(
        subjectLabel: widget.subjectLabel,
        lectures: widget.lectures,
        topics: widget.topics,
      );
      await _tutor.start(
        instructions: briefing,
        voice: NeuralVoice.realtimeId(ttsVoiceSettings.name),
      );
      widget.progressService?.increment(recalls: 1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = RealtimePhase.error;
      });
    }
  }

  @override
  void dispose() {
    _tutor.onPhase = null;
    _tutor.onLine = null;
    _tutor.onError = null;
    _tutor.onLevel = null;
    _tutor.stop();
    _level.dispose();
    _ask.dispose();
    super.dispose();
  }

  bool get _live =>
      _phase == RealtimePhase.listening ||
      _phase == RealtimePhase.userSpeaking ||
      _phase == RealtimePhase.tutorSpeaking;

  VoiceOrbMood get _mood {
    if (_error != null || _phase == RealtimePhase.error) {
      return VoiceOrbMood.error;
    }
    return switch (_phase) {
      RealtimePhase.connecting => VoiceOrbMood.connecting,
      RealtimePhase.listening =>
        _muted ? VoiceOrbMood.idle : VoiceOrbMood.listening,
      RealtimePhase.userSpeaking => VoiceOrbMood.hearing,
      RealtimePhase.tutorSpeaking => VoiceOrbMood.speaking,
      RealtimePhase.error => VoiceOrbMood.error,
      RealtimePhase.stopped => VoiceOrbMood.idle,
    };
  }

  String get _status {
    if (_error != null) return _error!;
    return switch (_phase) {
      RealtimePhase.connecting => 'Connecting…',
      RealtimePhase.listening => _muted
          ? 'Muted — unmute to talk'
          : 'Listening — ask anything from the notes',
      RealtimePhase.userSpeaking => 'Hearing you…',
      RealtimePhase.tutorSpeaking => 'Speaking — tap the circle to interrupt',
      RealtimePhase.error => _error ?? 'Something went wrong',
      RealtimePhase.stopped => 'Session ended',
    };
  }

  Future<void> _onOrbTap() async {
    if (_phase == RealtimePhase.tutorSpeaking) {
      await _tutor.interrupt();
      return;
    }
    if (_phase == RealtimePhase.error || _phase == RealtimePhase.stopped) {
      await _connect();
    }
  }

  Future<void> _sendTyped() async {
    final text = _ask.text.trim();
    if (text.isEmpty || !_live) return;
    _ask.clear();
    await _tutor.sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final last = _lines.isEmpty ? null : _lines.last;
    return ListView(
      padding: EdgeInsets.fromLTRB(t.gap(2.5), t.gap(1), t.gap(2.5), t.gap(2)),
      children: [
        Text(
          'Voice chat',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: t.gap(0.5)),
        Text(
          '${widget.lectures.length} lecture(s) · ${widget.topics.length} concept(s) in ${widget.subjectLabel}',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        SizedBox(height: t.gap(3)),
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: _level,
            builder: (context, level, _) {
              return VoiceOrb(
                mood: _mood,
                level: _muted ? 0 : level,
                onTap: _onOrbTap,
              );
            },
          ),
        ),
        SizedBox(height: t.gap(2)),
        Text(
          _status,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        if (last != null) ...[
          SizedBox(height: t.gap(1.25)),
          Text(
            last.fromTutor ? 'Tutor' : 'You',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.primaryAction,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          SizedBox(height: t.gap(0.4)),
          MathText(
            last.text,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, height: 1.4),
          ),
        ],
        SizedBox(height: t.gap(3)),
        TextField(
          controller: _ask,
          enabled: _live,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendTyped(),
          decoration: InputDecoration(
            hintText: 'Type a question if you would rather not speak',
            suffixIcon: IconButton(
              tooltip: 'Send',
              onPressed: _live ? _sendTyped : null,
              icon: const Icon(Icons.send_outlined),
            ),
          ),
        ),
        SizedBox(height: t.gap(1.5)),
        Row(
          children: [
            Expanded(
              child: SgSecondaryButton(
                label: _muted ? 'Unmute' : 'Mute',
                icon: _muted ? Icons.mic_off : Icons.mic_none,
                onPressed: _live
                    ? () async {
                        final next = !_muted;
                        await _tutor.setMuted(next);
                        if (mounted) setState(() => _muted = next);
                      }
                    : null,
              ),
            ),
            SizedBox(width: t.gap(1)),
            Expanded(
              child: _phase == RealtimePhase.error ||
                      _phase == RealtimePhase.stopped
                  ? SgPrimaryButton(
                      label: 'Retry',
                      expanded: true,
                      onPressed: _connect,
                    )
                  : SgPrimaryButton(
                      label: 'End',
                      expanded: true,
                      onPressed: () async {
                        await _tutor.stop();
                        if (mounted) {
                          setState(() => _phase = RealtimePhase.stopped);
                        }
                      },
                    ),
            ),
          ],
        ),
        SizedBox(height: t.gap(2)),
        TextButton(
          onPressed: () => setState(() => _showTranscript = !_showTranscript),
          child: Text(_showTranscript ? 'Hide transcript' : 'Show transcript'),
        ),
        if (_showTranscript) ...[
          if (_lines.isEmpty)
            Text(
              'What you both say will show up here.',
              style: TextStyle(color: t.textMuted),
            )
          else
            ..._lines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: t.gap(1)),
                child: SgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.fromTutor ? 'Tutor' : 'You',
                        style: TextStyle(
                          color: t.primaryAction,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: t.gap(0.5)),
                      MathText(line.text, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
