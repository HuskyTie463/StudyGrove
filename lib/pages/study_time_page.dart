import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/study_time_service.dart';
import '../services/subject_service.dart';
import '../ui/sg_primitives.dart';
import '../ui/shared_ui.dart';
import '../ui/shell_scope.dart';
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
        padding: const EdgeInsets.all(18),
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
                      studyTimeService: studyTimeService,
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

enum _TimeOverview { graph, rings }

class _StudyTimeBody extends StatefulWidget {
  const _StudyTimeBody({
    required this.panelOpacity,
    required this.subjects,
    required this.allSubjects,
    required this.totals,
    required this.studyTimeService,
  });

  final double panelOpacity;
  final List<Subject> subjects;
  final List<Subject> allSubjects;
  final List<StudyDayTotal> totals;
  final StudyTimeService studyTimeService;

  @override
  State<_StudyTimeBody> createState() => _StudyTimeBodyState();
}

class _StudyTimeBodyState extends State<_StudyTimeBody> {
  _TimeOverview _overview = _TimeOverview.graph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subjects = widget.subjects;
    final ringSubjects = widget.allSubjects;
    final totals = widget.totals;
    final studyTimeService = widget.studyTimeService;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubjectFilter(allSubjects: widget.allSubjects),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SgSegmented<_TimeOverview>(
                selected: _overview,
                onChanged: (v) => setState(() => _overview = v),
                segments: const [
                  ButtonSegment(
                    value: _TimeOverview.graph,
                    label: Text('Graph'),
                    icon: Icon(Icons.bar_chart_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _TimeOverview.rings,
                    label: Text('Rings'),
                    icon: Icon(Icons.donut_large_outlined, size: 18),
                  ),
                ],
              ),
            ),
            if (_overview == _TimeOverview.rings) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _changeGoal(context, studyTimeService),
                child: const Text('Change goal'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FrostPanel(
          opacity: widget.panelOpacity,
          child: _LiveStudyRow(
            subjects: ringSubjects,
            studyTimeService: studyTimeService,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FrostPanel(
            opacity: widget.panelOpacity,
            child: (_overview == _TimeOverview.rings
                    ? ringSubjects
                    : subjects)
                .isEmpty
                ? Text(
                    'Add a subject first, then you can time study against it.',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.84),
                    ),
                  )
                : SizedBox.expand(
                    child: _overview == _TimeOverview.graph
                        ? _WeekSubjectChart(
                            subjects: subjects,
                            days: weekDays,
                            minutesOn: minutesOn,
                          )
                        : _WeekRings(
                            subjects: ringSubjects,
                            weekMinutes: {
                              for (final s in ringSubjects)
                                s.id: weekFor(s.id),
                            },
                            targetMinutes:
                                studyTimeService.weekGoalMinutes,
                            onOpen: openSubject,
                          ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeGoal(
    BuildContext context,
    StudyTimeService studyTimeService,
  ) async {
    final current = studyTimeService.weekGoalHours;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        var hours = current;
        return AlertDialog(
          title: const Text('Weekly goal'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$hours hours per subject'),
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
    if (picked != null) {
      await studyTimeService.setWeekGoalHours(picked);
    }
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
    var maxTotal = 0;
    for (var i = 0; i < days.length; i++) {
      final key = dayKey(days[i]);
      var cursor = 0.0;
      final stacks = <BarChartRodStackItem>[];
      for (final s in subjects) {
        final m = minutesOn(s.id, key).toDouble();
        if (m <= 0) continue;
        stacks.add(BarChartRodStackItem(cursor, cursor + m, s.color));
        cursor += m;
      }
      final total = cursor.round();
      if (total > maxTotal) maxTotal = total;
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
    final maxY = (maxTotal + 10).clamp(30, 24 * 60).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: scheme.outline.withValues(alpha: 0.18),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
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
  final int targetMinutes;
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
                  targetMinutes: targetMinutes,
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
    final progress = targetMinutes <= 0
        ? 0.0
        : (minutes / targetMinutes).clamp(0.0, 1.0);
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
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
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
      old.progress != progress || old.color != color;
}

class _SubjectFilter extends StatelessWidget {
  const _SubjectFilter({required this.allSubjects});

  final List<Subject> allSubjects;

  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.of(context);
    final current = scope.subjectId;
    final value = (current != null && allSubjects.any((s) => s.id == current))
        ? current
        : _allValue;
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Subject',
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: _allValue, child: Text('All subjects')),
        for (final s in allSubjects)
          DropdownMenuItem(value: s.id, child: Text(s.label)),
      ],
      onChanged: (id) {
        if (id == null || id == _allValue) {
          scope.setSubjectId(null);
        } else {
          scope.setSubjectId(id);
        }
      },
    );
  }
}

class _LiveStudyRow extends StatefulWidget {
  const _LiveStudyRow({
    required this.subjects,
    required this.studyTimeService,
  });

  final List<Subject> subjects;
  final StudyTimeService studyTimeService;

  @override
  State<_LiveStudyRow> createState() => _LiveStudyRowState();
}

class _LiveStudyRowState extends State<_LiveStudyRow> {
  @override
  Widget build(BuildContext context) {
    final subjects = widget.subjects;
    final studyTimeService = widget.studyTimeService;
    final live = studyTimeService.isLive;
    final elapsed = studyTimeService.liveElapsed;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final focusId = ShellScope.maybeOf(context)?.subjectId;
    final selectedId = live
        ? studyTimeService.activeSubjectId
        : (focusId != null && subjects.any((s) => s.id == focusId)
            ? focusId
            : null);
    final dropdownValue = (selectedId != null &&
            subjects.any((s) => s.id == selectedId))
        ? selectedId
        : '__all__';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Studying now',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 10),
        if (subjects.isEmpty)
          const Text('Add a subject to start a timer.')
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(dropdownValue),
                  initialValue: dropdownValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('All subjects'),
                    ),
                    for (final s in subjects)
                      DropdownMenuItem(value: s.id, child: Text(s.label)),
                  ],
                  onChanged: live
                      ? null
                      : (id) {
                          final scope = ShellScope.maybeOf(context);
                          if (id == null || id == '__all__') {
                            scope?.setSubjectId(null);
                          } else {
                            scope?.setSubjectId(id);
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$mm:$ss',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () async {
                  if (live) {
                    await studyTimeService.stopLive();
                    return;
                  }
                  final id = selectedId;
                  if (id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pick a subject to start the timer.'),
                      ),
                    );
                    return;
                  }
                  await studyTimeService.startLive(id);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(live ? Icons.stop : Icons.play_arrow, size: 20),
                    const SizedBox(width: 6),
                    Text(live ? 'Stop' : 'Start'),
                  ],
                ),
              ),
            ],
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
            'Minutes over the last 7 days.',
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
            'Minutes over the last 8 weeks.',
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
    final maxY = (values.fold<int>(0, (a, b) => a > b ? a : b) + 10)
        .clamp(15, 24 * 60)
        .toDouble();
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outline.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
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
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
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

DateTime _mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[d.weekday - 1];
}
