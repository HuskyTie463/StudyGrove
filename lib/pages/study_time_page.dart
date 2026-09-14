import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/study_time_service.dart';
import '../services/subject_service.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';
import '../ui/shared_ui.dart';
import '../utils/datetime_utils.dart';

class StudyTimePage extends StatelessWidget {
  const StudyTimePage({
    super.key,
    required this.panelOpacity,
    required this.subjectService,
    required this.studyTimeService,
    this.focusSubjectId,
  });

  final double panelOpacity;
  final SubjectService subjectService;
  final StudyTimeService studyTimeService;
  final String? focusSubjectId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: StreamBuilder<List<Subject>>(
          stream: subjectService.streamSubjects(),
          builder: (context, subSnap) {
            final all = subSnap.data ?? const <Subject>[];
            final subjects = focusSubjectId == null
                ? all
                : all.where((s) => s.id == focusSubjectId).toList();
            return StreamBuilder<List<StudyDayTotal>>(
              stream: studyTimeService.streamTotals(),
              builder: (context, timeSnap) {
                final totals = timeSnap.data ?? const <StudyDayTotal>[];
                return AnimatedBuilder(
                  animation: studyTimeService,
                  builder: (context, _) {
                    return _StudyTimeBody(
                      panelOpacity: panelOpacity,
                      subjects: subjects,
                      allSubjects: all,
                      totals: totals,
                      subjectService: subjectService,
                      studyTimeService: studyTimeService,
                      focusSubjectId: focusSubjectId,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _TimeLane { subjects, hobbies }

enum _TimeOverview { graph, rings }

class _StudyTimeBody extends StatefulWidget {
  const _StudyTimeBody({
    required this.panelOpacity,
    required this.subjects,
    required this.allSubjects,
    required this.totals,
    required this.subjectService,
    required this.studyTimeService,
    this.focusSubjectId,
  });

  final double panelOpacity;
  final List<Subject> subjects;
  final List<Subject> allSubjects;
  final List<StudyDayTotal> totals;
  final SubjectService subjectService;
  final StudyTimeService studyTimeService;
  final String? focusSubjectId;

  @override
  State<_StudyTimeBody> createState() => _StudyTimeBodyState();
}

class _StudyTimeBodyState extends State<_StudyTimeBody> {
  _TimeLane _lane = _TimeLane.subjects;
  _TimeOverview _overview = _TimeOverview.graph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 800;
    final hobbiesLane = _lane == _TimeLane.hobbies;
    final laneAll = widget.allSubjects
        .where((s) => hobbiesLane ? s.isHobby : !s.isHobby)
        .toList();
    final subjects = widget.subjects
        .where((s) => hobbiesLane ? s.isHobby : !s.isHobby)
        .toList();
    final visible = subjects.isEmpty ? laneAll : subjects;
    final ringSubjects = visible;
    final totals = widget.totals;
    final studyTimeService = widget.studyTimeService;
    final focusSubject = visible.length == 1 ? visible.first : null;
    final today = dayKey(DateTime.now());
    final weekStart = _mondayOf(DateTime.now());
    final weekDays = [
      for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
    ];
    final weekKeys = {for (final d in weekDays) dayKey(d)};

    int liveExtra(String id) {
      if (!studyTimeService.isLive || studyTimeService.activeSubjectId != id) {
        return 0;
      }
      return studyTimeService.liveElapsed.inMinutes;
    }

    int minutesOn(String id, String key) {
      var n = totals
          .where((t) => t.subjectId == id && t.dayKey == key)
          .fold(0, (sum, t) => sum + t.minutes);
      if (key == today) n += liveExtra(id);
      return n;
    }

    int weekFor(String id) =>
        weekKeys.fold(0, (n, key) => n + minutesOn(id, key));

    void openSubject(Subject s) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyTimeSubjectPage(
            subject: s,
            totals: totals.where((t) => t.subjectId == s.id).toList(),
          ),
        ),
      );
    }

    final laneToggle = SgSegmented<_TimeLane>(
      selected: _lane,
      onChanged: (v) => setState(() => _lane = v),
      segments: const [
        ButtonSegment(
          value: _TimeLane.subjects,
          label: Text('Subjects'),
        ),
        ButtonSegment(
          value: _TimeLane.hobbies,
          label: Text('Hobbies'),
        ),
      ],
    );
    final overviewToggle = SgSegmented<_TimeOverview>(
      selected: _overview,
      onChanged: (v) => setState(() => _overview = v),
      segments: const [
        ButtonSegment(
          value: _TimeOverview.graph,
          label: Text('Graph'),
        ),
        ButtonSegment(
          value: _TimeOverview.rings,
          label: Text('Rings'),
        ),
      ],
    );
    final goalButton = _overview == _TimeOverview.rings
        ? TextButton(
            onPressed: () => _changeGoal(
              context,
              studyTimeService,
              focusSubject,
              laneAll,
            ),
            child: const Text('Goal'),
          )
        : null;
    final hobbyAdd = hobbiesLane
        ? IconButton(
            tooltip: 'Add hobby',
            visualDensity: VisualDensity.compact,
            onPressed: () => _addHobby(context),
            icon: const Icon(Icons.add, size: 20),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        compact
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  laneToggle,
                  if (hobbyAdd != null) hobbyAdd,
                  overviewToggle,
                  if (goalButton != null) goalButton,
                ],
              )
            : Row(
                children: [
                  laneToggle,
                  if (hobbyAdd != null) hobbyAdd,
                  const Spacer(),
                  overviewToggle,
                  if (goalButton != null) goalButton,
                ],
              ),
        const SizedBox(height: 10),
        _LiveStudyRow(
          subjects: laneAll,
          allSubjects: widget.allSubjects,
          studyTimeService: studyTimeService,
          hobbiesLane: hobbiesLane,
          chromeSubjectId: widget.focusSubjectId,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FrostPanel(
            opacity: widget.panelOpacity,
            child: visible.isEmpty
                ? _EmptyLane(
                    hobbies: hobbiesLane,
                    onAddHobby:
                        hobbiesLane ? () => _addHobby(context) : null,
                    color: scheme.onSurface.withValues(alpha: 0.84),
                  )
                : SizedBox.expand(
                    child: _overview == _TimeOverview.graph
                        ? _WeekSubjectChart(
                            subjects: visible,
                            days: weekDays,
                            minutesOn: minutesOn,
                          )
                        : _WeekRings(
                            subjects: ringSubjects,
                            weekMinutes: {
                              for (final s in ringSubjects)
                                s.id: weekFor(s.id),
                            },
                            targetMinutes: {
                              for (final s in ringSubjects)
                                s.id: studyTimeService.goalMinutesFor(s),
                            },
                            onOpen: openSubject,
                          ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _addHobby(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var colorValue = kSubjectColorPalette.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add hobby'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Piano',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Colour',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in kSubjectColorPalette)
                      InkWell(
                        onTap: () => setDialogState(() => colorValue = c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorValue == c
                                  ? Theme.of(ctx).colorScheme.onSurface
                                  : Theme.of(ctx)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.35),
                              width: colorValue == c ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    await widget.subjectService.addSubject(
      name: name,
      colorValue: colorValue,
      kind: SubjectKind.hobby,
    );
  }

  Future<void> _changeGoal(
    BuildContext context,
    StudyTimeService studyTimeService,
    Subject? focusSubject,
    List<Subject> laneSubjects,
  ) async {
    final editingSubject = focusSubject;
    final current = editingSubject == null
        ? studyTimeService.weekGoalHours
        : studyTimeService.goalHoursFor(editingSubject);
    final combined = studyTimeService.combinedGoalHours(laneSubjects);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        var hours = current.clamp(1, 20);
        return AlertDialog(
          title: Text(
            editingSubject == null
                ? 'Default weekly goal'
                : 'Weekly goal',
          ),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    editingSubject == null
                        ? '$hours hours for subjects without their own goal'
                        : '$hours hours for ${editingSubject.name}',
                  ),
                  if (editingSubject == null && laneSubjects.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'All together: ${combined}h this week',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  Slider(
                    value: hours.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${hours}h',
                    onChanged: (v) => setLocal(() => hours = v.round()),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, hours),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    if (editingSubject != null) {
      await widget.subjectService.updateWeekGoalHours(
        id: editingSubject.id,
        hours: picked,
      );
    } else {
      await studyTimeService.setWeekGoalHours(picked);
    }
  }
}

class _EmptyLane extends StatelessWidget {
  const _EmptyLane({
    required this.hobbies,
    required this.color,
    this.onAddHobby,
  });

  final bool hobbies;
  final Color color;
  final VoidCallback? onAddHobby;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hobbies
              ? 'Add a hobby first, then you can time it.'
              : 'Add a subject first, then you can time study against it.',
          style: TextStyle(color: color),
        ),
        if (onAddHobby != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddHobby,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add hobby'),
          ),
        ],
      ],
    );
  }
}

class _WeekSubjectChart extends StatelessWidget {
  const _WeekSubjectChart({
    required this.subjects,
    required this.days,
    required this.minutesOn,
  });

  final List<Subject> subjects;
  final List<DateTime> days;
  final int Function(String subjectId, String key) minutesOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <BarChartGroupData>[];
    var maxHours = 0.0;
    for (var i = 0; i < days.length; i++) {
      final key = dayKey(days[i]);
      var cursor = 0.0;
      final stacks = <BarChartRodStackItem>[];
      for (final s in subjects) {
        final h = studyMinutesToHours(minutesOn(s.id, key));
        if (h <= 0) continue;
        stacks.add(BarChartRodStackItem(cursor, cursor + h, s.color));
        cursor += h;
      }
      if (cursor > maxHours) maxHours = cursor;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cursor == 0 ? 0 : cursor,
              width: 18,
              borderRadius: BorderRadius.circular(6),
              color: stacks.isEmpty
                  ? scheme.outline.withValues(alpha: 0.22)
                  : stacks.last.color,
              rodStackItems: stacks,
            ),
          ],
        ),
      );
    }
    final maxY = studyTimeChartMaxHours(maxHours);
    final hourStep = studyTimeChartHourInterval(maxY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: hourStep,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: scheme.outline.withValues(alpha: 0.18),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: _hoursBarTouchData(scheme),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: _hoursLeftTitles(scheme, hourStep),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _weekdayShort(days[i]),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final s in subjects)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekRings extends StatelessWidget {
  const _WeekRings({
    required this.subjects,
    required this.weekMinutes,
    required this.targetMinutes,
    required this.onOpen,
  });

  final List<Subject> subjects;
  final Map<String, int> weekMinutes;
  final Map<String, int> targetMinutes;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = subjects.length.clamp(1, 12);
        final cols = count <= 2 ? count : (count <= 6 ? 2 : 3);
        final gap = 20.0;
        final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final rows = (count / cols).ceil().clamp(1, 6);
        final cellH = (constraints.maxHeight - gap * (rows - 1)) / rows;
        final ring = (cellW < cellH ? cellW : cellH).clamp(150.0, 280.0);
        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final s in subjects)
                _SubjectHourCircle(
                  subject: s,
                  minutes: weekMinutes[s.id] ?? 0,
                  targetMinutes: targetMinutes[s.id] ?? 0,
                  size: ring,
                  onTap: () => onOpen(s),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectHourCircle extends StatelessWidget {
  const _SubjectHourCircle({
    required this.subject,
    required this.minutes,
    required this.targetMinutes,
    required this.size,
    required this.onTap,
  });

  final Subject subject;
  final int minutes;
  final int targetMinutes;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = studyGoalRatio(minutes, targetMinutes);
    final goalHours = (targetMinutes / 60).round();
    final ringSize = (size - 36).clamp(120.0, 240.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CustomPaint(
                painter: _FillCirclePainter(
                  progress: progress,
                  color: subject.color,
                  track: subject.color.withValues(alpha: 0.16),
                  ring: scheme.outline.withValues(alpha: 0.22),
                ),
                child: Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: ringSize > 180 ? 28 : 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subject.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: ringSize > 180 ? 16 : 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${formatStudyMinutes(minutes)} / ${goalHours}h',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillCirclePainter extends CustomPainter {
  const _FillCirclePainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.ring,
  });

  final double progress;
  final Color color;
  final Color track;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = (size.shortestSide * 0.12).clamp(14.0, 22.0);
    final r = size.shortestSide / 2 - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(c, r, trackPaint);
    final sweeps = studyRingLapSweeps(progress);
    for (var i = 0; i < sweeps.length; i++) {
      final sweep = sweeps[i];
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = studyRingLapColor(color, i),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(covariant _FillCirclePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.ring != ring;
}

class _LiveStudyRow extends StatefulWidget {
  const _LiveStudyRow({
    required this.subjects,
    required this.allSubjects,
    required this.studyTimeService,
    required this.hobbiesLane,
    this.chromeSubjectId,
  });

  final List<Subject> subjects;
  final List<Subject> allSubjects;
  final StudyTimeService studyTimeService;
  final bool hobbiesLane;
  final String? chromeSubjectId;

  @override
  State<_LiveStudyRow> createState() => _LiveStudyRowState();
}

class _LiveStudyRowState extends State<_LiveStudyRow> {
  String? _sessionSubjectId;

  bool _inLane(String? id) =>
      id != null && widget.subjects.any((s) => s.id == id);

  String? get _chromeInLane =>
      _inLane(widget.chromeSubjectId) ? widget.chromeSubjectId : null;

  String? get _pickedSubjectId {
    if (_chromeInLane != null) return _chromeInLane;
    if (_inLane(_sessionSubjectId)) return _sessionSubjectId;
    if (widget.subjects.length == 1) return widget.subjects.first.id;
    return null;
  }

  Subject? _named(String? id) {
    if (id == null) return null;
    for (final s in widget.allSubjects) {
      if (s.id == id) return s;
    }
    for (final s in widget.subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final subjects = widget.subjects;
    final studyTimeService = widget.studyTimeService;
    final live = studyTimeService.isLive;
    final elapsed = studyTimeService.liveElapsed;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final liveId = studyTimeService.activeSubjectId;
    final running = _named(liveId);
    final selectedId = live ? liveId : _pickedSubjectId;
    final showPicker = !live && _chromeInLane == null && subjects.length > 1;
    final labelSubject = live ? running : _named(selectedId);
    final itemHint = widget.hobbiesLane ? 'Hobby' : 'Subject';

    return Row(
      children: [
        Expanded(
          child: subjects.isEmpty
              ? Text(
                  widget.hobbiesLane
                      ? 'Add a hobby to start a timer.'
                      : 'Add a subject to start a timer.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                )
              : showPicker
                  ? DropdownButtonFormField<String>(
                      key: ValueKey('timer-$selectedId'),
                      initialValue: selectedId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: itemHint,
                        isDense: true,
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                      items: [
                        for (final s in subjects)
                          DropdownMenuItem(value: s.id, child: Text(s.label)),
                      ],
                      onChanged: (id) => setState(() => _sessionSubjectId = id),
                    )
                  : Text(
                      labelSubject?.label ?? itemHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.78),
                      ),
                    ),
        ),
        Text(
          '$mm:$ss',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: subjects.isEmpty
              ? null
              : () async {
                  if (live) {
                    await studyTimeService.stopLive();
                    return;
                  }
                  final id = selectedId;
                  if (id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.hobbiesLane
                              ? 'Pick a hobby to start the timer.'
                              : 'Pick a subject to start the timer.',
                        ),
                      ),
                    );
                    return;
                  }
                  await studyTimeService.startLive(id);
                },
          style: live
              ? FilledButton.styleFrom(
                  backgroundColor: t.urgent,
                  foregroundColor: _onSoftStop(t.urgent),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(live ? Icons.stop : Icons.play_arrow, size: 20),
              const SizedBox(width: 6),
              Text(live ? 'Stop' : 'Start'),
            ],
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: subjects.isEmpty ? null : _addManualTime,
          child: const Text('Add time'),
        ),
      ],
    );
  }

  Future<void> _addManualTime() async {
    final logged = await showDialog<(String, int)?>(
      context: context,
      builder: (ctx) => AddManualTimeDialog(
        subjects: widget.subjects,
        initialSubjectId: _pickedSubjectId,
        hobbiesLane: widget.hobbiesLane,
      ),
    );
    if (!mounted || logged == null) return;
    await widget.studyTimeService.addMinutes(
      subjectId: logged.$1,
      minutes: logged.$2,
      source: 'manual',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${formatStudyMinutes(logged.$2)}.'),
      ),
    );
  }
}

Color _onSoftStop(Color bg) {
  return bg.computeLuminance() > 0.45
      ? const Color(0xFF2A1612)
      : Colors.white;
}

class AddManualTimeDialog extends StatefulWidget {
  const AddManualTimeDialog({
    super.key,
    required this.subjects,
    this.initialSubjectId,
    this.hobbiesLane = false,
  });

  final List<Subject> subjects;
  final String? initialSubjectId;
  final bool hobbiesLane;

  @override
  State<AddManualTimeDialog> createState() => _AddManualTimeDialogState();
}

class _AddManualTimeDialogState extends State<AddManualTimeDialog> {
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minsCtrl;
  String? _subjectId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hoursCtrl = TextEditingController(text: '0');
    _minsCtrl = TextEditingController(text: '30');
    final initial = widget.initialSubjectId;
    if (initial != null && widget.subjects.any((s) => s.id == initial)) {
      _subjectId = initial;
    } else if (widget.subjects.length == 1) {
      _subjectId = widget.subjects.first.id;
    }
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = int.tryParse(_hoursCtrl.text.trim()) ?? -1;
    final minutes = int.tryParse(_minsCtrl.text.trim()) ?? -1;
    final total = parseManualStudyMinutes(hours: hours, minutes: minutes);
    final id = _subjectId;
    if (id == null || id.isEmpty) {
      setState(() {
        _error = widget.hobbiesLane
            ? 'Pick a hobby for this time.'
            : 'Pick a subject for this time.';
      });
      return;
    }
    if (total == null) {
      setState(() => _error = 'Enter at least 1 minute.');
      return;
    }
    Navigator.pop(context, (id, total));
  }

  @override
  Widget build(BuildContext context) {
    final itemLabel = widget.hobbiesLane ? 'Hobby' : 'Subject';
    return AlertDialog(
      title: const Text('Add time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: itemLabel,
              ),
              items: [
                for (final s in widget.subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.label)),
              ],
              onChanged: (id) => setState(() {
                _subjectId = id;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('manual_hours'),
                    controller: _hoursCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('manual_minutes'),
                    controller: _minsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class StudyTimeSubjectPage extends StatelessWidget {
  const StudyTimeSubjectPage({
    super.key,
    required this.subject,
    required this.totals,
  });

  final Subject subject;
  final List<StudyDayTotal> totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i)),
    );
    final weeks = List<DateTime>.generate(8, (i) {
      final monday = _mondayOf(now).subtract(Duration(days: 7 * (7 - i)));
      return monday;
    });

    final byDay = {for (final t in totals) t.dayKey: t.minutes};
    final dayValues = [
      for (final d in days) byDay[dayKey(d)] ?? 0,
    ];
    final weekValues = [
      for (final monday in weeks)
        List.generate(7, (i) => byDay[dayKey(monday.add(Duration(days: i)))] ?? 0)
            .fold(0, (a, b) => a + b),
    ];

    final todayMins = byDay[dayKey(now)] ?? 0;
    final thisWeek = weekValues.isEmpty ? 0 : weekValues.last;

    return Scaffold(
      appBar: AppBar(title: Text(subject.label)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GreenChip('Today ${formatStudyMinutes(todayMins)}'),
              GreenChip('This week ${formatStudyMinutes(thisWeek)}'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Each day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hours over the last 7 days.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _MinutesChart(
              values: dayValues,
              labels: [for (final d in days) _weekdayShort(d)],
              color: subject.color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Each week',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hours over the last 8 weeks.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _MinutesChart(
              values: weekValues,
              labels: [
                for (final monday in weeks) '${monday.day}/${monday.month}',
              ],
              color: subject.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinutesChart extends StatelessWidget {
  const _MinutesChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var maxHours = 0.0;
    final hourValues = <double>[
      for (final minutes in values) studyMinutesToHours(minutes),
    ];
    for (final h in hourValues) {
      if (h > maxHours) maxHours = h;
    }
    final maxY = studyTimeChartMaxHours(maxHours, cap: 80);
    final hourStep = studyTimeChartHourInterval(maxY);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: hourStep,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outline.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: _hoursBarTouchData(scheme),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: _hoursLeftTitles(scheme, hourStep),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < hourValues.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: hourValues[i],
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  color: color,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

AxisTitles _hoursLeftTitles(ColorScheme scheme, double interval) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 40,
      interval: interval,
      getTitlesWidget: (v, _) {
        if (v < -0.001) return const SizedBox.shrink();
        return Text(
          formatStudyChartHours(v),
          style: TextStyle(
            fontSize: 10,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        );
      },
    ),
  );
}

BarTouchData _hoursBarTouchData(ColorScheme scheme) {
  return BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => scheme.surface.withValues(alpha: 0.94),
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        return BarTooltipItem(
          formatStudyChartHours(rod.toY),
          TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
      },
    ),
  );
}

DateTime _mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[d.weekday - 1];
}
