import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/event_service.dart';
import '../services/subject_service.dart';
import '../ui/shared_ui.dart';
import '../utils/datetime_utils.dart' as du;

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.panelOpacity,
    required this.eventService,
    required this.subjectService,
  });

  final double panelOpacity;
  final EventService eventService;
  final SubjectService subjectService;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime selected = DateTime.now();
  DateTime? _cachedStreamDay;
  Stream<List<AppEvent>>? _eventsStream;
  DateTime? _cachedMonth;
  Stream<Map<String, List<String?>>>? _monthSubjectIdsStream;
  late final Stream<List<Subject>> _subjectsStream;

  @override
  void initState() {
    super.initState();
    _subjectsStream = widget.subjectService.streamSubjects();
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Stream<List<AppEvent>> _getEventsStream(DateTime day) {
    final d = _dayKey(day);
    if (_cachedStreamDay != null &&
        _cachedStreamDay!.year == d.year &&
        _cachedStreamDay!.month == d.month &&
        _cachedStreamDay!.day == d.day) {
      return _eventsStream!;
    }
    _cachedStreamDay = d;
    _eventsStream = widget.eventService.streamCombinedEventsForDay(d);
    return _eventsStream!;
  }

  Stream<Map<String, List<String?>>> _getMonthSubjectIdsStream(DateTime m) {
    final key = DateTime(m.year, m.month, 1);
    if (_cachedMonth != null &&
        _cachedMonth!.year == key.year &&
        _cachedMonth!.month == key.month) {
      return _monthSubjectIdsStream!;
    }
    _cachedMonth = key;
    _monthSubjectIdsStream =
        widget.eventService.streamMonthEventSubjectIds(key);
    return _monthSubjectIdsStream!;
  }

  Color _subjectColor(
    String? subjectId,
    Map<String, Subject> byId,
    ColorScheme scheme,
  ) {
    if (subjectId != null && byId.containsKey(subjectId)) {
      return byId[subjectId]!.color;
    }
    return scheme.primary;
  }

  Widget _eventBars(
    List<String?> subjectIds, {
    required Map<String, Subject> byId,
    required ColorScheme scheme,
  }) {
    if (subjectIds.isEmpty) return const SizedBox.shrink();
    final show = subjectIds.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          for (var i = 0; i < show.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _subjectColor(show[i], byId, scheme),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          if (subjectIds.length > 3) ...[
            const SizedBox(width: 2),
            Text(
              '+',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface.withValues(alpha: 0.84),
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DateTime?> _buildMonthCells(DateTime m) {
    final first = DateTime(m.year, m.month, 1);
    final last = DateTime(m.year, m.month + 1, 0);
    final leadingEmpty = first.weekday - 1;

    final cells = <DateTime?>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= last.day; d++) {
      cells.add(DateTime(m.year, m.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  Widget _weekdayHeader() {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Row(
          children: days
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${months[d.month - 1]} ${d.year}";
  }

  String _shortDate(DateTime d) => "${d.day}/${d.month}/${d.year}";

  Future<bool> _confirm(BuildContext context, String msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _promptAddEvent(
    BuildContext context,
    List<Subject> subjects,
  ) async {
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    TimeOfDay pickedTime = TimeOfDay.now();
    TimeOfDay pickedEnd = du.minutesToTimeOfDay(
      du.resolveEndMinutes(du.timeToMinutes(pickedTime), null),
    );
    bool repeatWeekly = false;
    String? subjectId;

    void ensureEndAfterStart(void Function(void Function()) setDialogState) {
      final startMins = du.timeToMinutes(pickedTime);
      if (du.timeToMinutes(pickedEnd) <= startMins) {
        setDialogState(() {
          pickedEnd = du.minutesToTimeOfDay(
            du.resolveEndMinutes(startMins, null),
          );
        });
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Add event"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "e.g., tutorial / meeting",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    hintText: "Location (optional)",
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...subjects.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => subjectId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GreenChip("Start: ${pickedTime.format(ctx)}"),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: pickedTime,
                        );
                        if (t != null) {
                          setState(() => pickedTime = t);
                          ensureEndAfterStart(setState);
                        }
                      },
                      child: const Text("Pick start"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GreenChip("End: ${pickedEnd.format(ctx)}"),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: pickedEnd,
                        );
                        if (t != null) {
                          setState(() => pickedEnd = t);
                          ensureEndAfterStart(setState);
                        }
                      },
                      child: const Text("Pick end"),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: repeatWeekly,
                  onChanged: (v) => setState(() => repeatWeekly = v ?? false),
                  title: const Text(
                    "Repeat weekly (e.g. timetable class)",
                    style: TextStyle(fontSize: 14),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );

    final title = titleCtrl.text.trim();
    final loc = locCtrl.text.trim();
    titleCtrl.dispose();
    locCtrl.dispose();
    if (ok == true && title.isNotEmpty) {
      final startMins = du.timeToMinutes(pickedTime);
      final endTime = du.minutesToTimeOfDay(
        du.resolveEndMinutes(startMins, du.timeToMinutes(pickedEnd)),
      );
      if (repeatWeekly) {
        await widget.eventService.addRecurringEvent(
          weekday: selected.weekday,
          title: title,
          time: pickedTime,
          endTime: endTime,
          location: loc.isEmpty ? null : loc,
          subjectId: subjectId,
        );
      } else {
        await widget.eventService.addEvent(
          day: _dayKey(selected),
          title: title,
          time: pickedTime,
          endTime: endTime,
          location: loc.isEmpty ? null : loc,
          subjectId: subjectId,
        );
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final days = _buildMonthCells(month);
    final selectedKey = _dayKey(selected);
    final todayKey = _dayKey(DateTime.now());

    return StreamBuilder<List<Subject>>(
      stream: _subjectsStream,
      builder: (context, subjectSnap) {
        final subjects = subjectSnap.data ?? const <Subject>[];
        final byId = {for (final s in subjects) s.id: s};

        Widget calendarPanel() => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Calendar",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month - 1, 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Flexible(
                    child: Text(
                      _monthLabel(month),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month + 1, 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _weekdayHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<Map<String, List<String?>>>(
                  stream: _getMonthSubjectIdsStream(month),
                  builder: (context, countSnap) {
                    final byDay =
                        countSnap.data ?? const <String, List<String?>>{};
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final rows = (days.length / 7).ceil().clamp(1, 6);
                        final cellH =
                            (constraints.maxHeight - (rows - 1) * 6) / rows;
                        final cellW =
                            (constraints.maxWidth - 6 * 6) / 7;
                        final ratio = (cellW / cellH).clamp(0.55, 1.2);
                        return GridView.builder(
                          itemCount: days.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: ratio,
                          ),
                          itemBuilder: (_, i) {
                            final cell = days[i];
                            if (cell == null) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: scheme.outline
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                              );
                            }

                            final cellKey = _dayKey(cell);
                            final isSelected = cellKey == selectedKey;
                            final isToday = cellKey == todayKey;
                            final subjectIds =
                                byDay[du.dayKey(cell)] ?? const [];

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => selected = cell),
                              child: Container(
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? scheme.primary.withValues(alpha: 0.55)
                                      : scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.50),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isToday
                                        ? scheme.primary
                                        : scheme.outline
                                            .withValues(alpha: 0.30),
                                    width: isToday ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: isWide ? 10 : 4,
                                        left: isWide ? 10 : 4,
                                      ),
                                      child: Text(
                                        "${cell.day}",
                                        style: TextStyle(
                                          fontSize: isWide ? 14 : 12,
                                          fontWeight: FontWeight.w800,
                                          color: isToday
                                              ? scheme.primary
                                              : scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (subjectIds.isNotEmpty)
                                      _eventBars(
                                        subjectIds,
                                        byId: byId,
                                        scheme: scheme,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );

        Widget eventsPanel() => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Events — ${_shortDate(selected)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _promptAddEvent(context, subjects),
                    icon: const Icon(Icons.add_alarm),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<AppEvent>>(
                  stream: _getEventsStream(selected),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = (snap.data ?? <AppEvent>[])
                      ..sort(
                        (a, b) => a.startMinutes.compareTo(b.startMinutes),
                      );

                    if (events.isEmpty) {
                      return Text(
                        "No events.",
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.84),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = events[i];
                        final time = du.formatTimeRange(
                          context,
                          e.startMinutes,
                          e.endMinutes,
                        );
                        final color = _subjectColor(e.subjectId, byId, scheme);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scheme.outline.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                time,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (e.isRecurring)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.repeat,
                                    size: 14,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.70),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  (e.location == null ||
                                          e.location!.trim().isEmpty)
                                      ? e.title
                                      : "${e.title} • ${e.location}",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: e.isRecurring
                                    ? "Delete recurring class"
                                    : "Delete",
                                onPressed: () async {
                                  final ok = await _confirm(
                                    context,
                                    e.isRecurring
                                        ? "Delete this weekly class from your timetable?"
                                        : "Delete this event?",
                                  );
                                  if (!ok) return;
                                  await widget.eventService
                                      .deleteEventOrRecurring(e.id);
                                  if (mounted) setState(() {});
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.70),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: isWide
                ? Row(
                    children: [
                      Expanded(flex: 7, child: calendarPanel()),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: eventsPanel()),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 520, child: calendarPanel()),
                        const SizedBox(height: 14),
                        SizedBox(height: 360, child: eventsPanel()),
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
