// lib/pages/pomodoro_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/study_time_service.dart';
import '../services/subject_service.dart';
import '../ui/shared_ui.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({
    super.key,
    required this.panelOpacity,
    required this.subjectService,
    required this.studyTimeService,
    this.initialSubjectId,
  });
  final double panelOpacity;
  final SubjectService subjectService;
  final StudyTimeService studyTimeService;
  final String? initialSubjectId;

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  int focusMinutes = 25;
  int breakMinutes = 5;

  bool running = false;
  bool onBreak = false;
  int secondsLeft = 25 * 60;
  int cyclesCompleted = 0;
  String? _subjectId;
  int _focusElapsedSeconds = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    secondsLeft = focusMinutes * 60;
    _subjectId = widget.initialSubjectId;
  }

  @override
  void didUpdateWidget(covariant PomodoroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubjectId != oldWidget.initialSubjectId &&
        widget.initialSubjectId != null &&
        !running) {
      _subjectId = widget.initialSubjectId;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get mode => onBreak ? "Break" : "Focus";

  String get timeText {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _start() {
    if (running) return;
    if (_subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a subject before starting.')),
      );
      return;
    }
    setState(() => running = true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (!onBreak) _focusElapsedSeconds += 1;

      if (secondsLeft <= 1) {
        _completeSegment();
      } else {
        setState(() => secondsLeft -= 1);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      running = false;
      onBreak = false;
      secondsLeft = focusMinutes * 60;
      _focusElapsedSeconds = 0;
    });
  }

  Future<void> _logFocusIfNeeded() async {
    final subjectId = _subjectId;
    final mins = (_focusElapsedSeconds / 60).round();
    _focusElapsedSeconds = 0;
    if (subjectId == null || mins < 1) return;
    await widget.studyTimeService.addMinutes(
      subjectId: subjectId,
      minutes: mins,
      source: 'pomodoro',
    );
  }

  void _completeSegment() {
    if (onBreak) {
      setState(() {
        onBreak = false;
        secondsLeft = focusMinutes * 60;
        cyclesCompleted += 1;
        _focusElapsedSeconds = 0;
      });
    } else {
      _logFocusIfNeeded();
      setState(() {
        onBreak = true;
        secondsLeft = breakMinutes * 60;
      });
    }
  }

  void _bumpFocus(int delta) {
    setState(() {
      focusMinutes = (focusMinutes + delta).clamp(1, 240);
      if (!running && !onBreak) secondsLeft = focusMinutes * 60;
      if (!running && onBreak == false) secondsLeft = focusMinutes * 60;
    });
  }

  void _bumpBreak(int delta) {
    setState(() {
      breakMinutes = (breakMinutes + delta).clamp(1, 120);
      if (!running && onBreak) secondsLeft = breakMinutes * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    Widget timerPanel(List<Subject> subjects) => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GreenChip(mode),
                  const SizedBox(width: 8),
                  GreenChip("Cycles: $cyclesCompleted"),
                ],
              ),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                Text(
                  'Add a subject first so this session can be counted on the Time tab.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: subjects.any((s) => s.id == _subjectId)
                      ? _subjectId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Required before start',
                  ),
                  items: [
                    for (final s in subjects)
                      DropdownMenuItem(value: s.id, child: Text(s.label)),
                  ],
                  onChanged: (running || widget.initialSubjectId != null)
                      ? null
                      : (id) => setState(() => _subjectId = id),
                ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    SoftButton(
                      label: "Start",
                      icon: Icons.play_arrow,
                      filled: true,
                      onPressed: running ? null : _start,
                    ),
                    SoftButton(
                      label: "Pause",
                      icon: Icons.pause,
                      onPressed: running ? _pause : null,
                    ),
                    SoftButton(
                      label: "Reset",
                      icon: Icons.restart_alt,
                      onPressed: _reset,
                    ),
                    SoftButton(
                      label: onBreak ? "Skip break" : "Skip focus",
                      icon: Icons.skip_next,
                      onPressed: () {
                        if (!onBreak) {
                          _logFocusIfNeeded();
                        }
                        setState(() {
                          if (onBreak) {
                            onBreak = false;
                            secondsLeft = focusMinutes * 60;
                            _focusElapsedSeconds = 0;
                          } else {
                            onBreak = true;
                            secondsLeft = breakMinutes * 60;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  running ? "Running" : "Idle",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                  ),
                ),
              ),
            ],
          ),
        );

    Widget settingsPanel() => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Timer settings", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              TimeStepperTile(
                label: "Focus (minutes)",
                minutes: focusMinutes,
                onMinus: () => _bumpFocus(-1),
                onPlus: () => _bumpFocus(1),
              ),
              const SizedBox(height: 12),
              TimeStepperTile(
                label: "Break (minutes)",
                minutes: breakMinutes,
                onMinus: () => _bumpBreak(-1),
                onPlus: () => _bumpBreak(1),
              ),
              const SizedBox(height: 16),
              const Text("Quick stats", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              QuickRow(label: "Mode", value: mode),
              QuickRow(label: "Time remaining", value: timeText),
              QuickRow(label: "Cycles completed", value: cyclesCompleted.toString()),
            ],
          ),
        );

    return StreamBuilder<List<Subject>>(
      stream: widget.subjectService.streamSubjects(),
      builder: (context, snap) {
        final subjects = snap.data ?? const <Subject>[];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: isWide
                ? Row(
                    children: [
                      Expanded(flex: 7, child: timerPanel(subjects)),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: settingsPanel()),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 560, child: timerPanel(subjects)),
                        const SizedBox(height: 14),
                        settingsPanel(),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}