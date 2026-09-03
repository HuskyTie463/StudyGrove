import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/event_service.dart';
import '../services/subject_service.dart';
import '../ui/shared_ui.dart';
import '../ui/shell_scope.dart';
import '../utils/datetime_utils.dart';

class WeeklyPlannerPage extends StatefulWidget {
  const WeeklyPlannerPage({
    super.key,
    required this.panelOpacity,
    required this.eventService,
    required this.subjectService,
  });

  final double panelOpacity;
  final EventService eventService;
  final SubjectService subjectService;

  @override
  State<WeeklyPlannerPage> createState() => _WeeklyPlannerPageState();
}

class _WeeklyPlannerPageState extends State<WeeklyPlannerPage> {
  late DateTime _weekStart = _startOfWeek(DateTime.now());
  DateTime? _cachedWeekStart;
  Stream<Map<String, List<AppEvent>>>? _weekStream;
  late final Stream<List<Subject>> _subjectsStream;
  List<Subject> _subjects = const [];

  static const double _pxPerMinute = 1.25;
  static const double _minBlockHeight = 36;
  static const int _defaultStartMinutes = 8 * 60;
  static const int _defaultEndMinutes = 18 * 60;
  static const int _rangePaddingMinutes = 30;

  @override
  void initState() {
    super.initState();
    _subjectsStream = widget.subjectService.streamSubjects();
  }

  Map<String, Subject> get _subjectsById =>
      {for (final s in _subjects) s.id: s};

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime _dayFromKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Stream<Map<String, List<AppEvent>>> _eventsForWeek() {
    if (_cachedWeekStart == _weekStart && _weekStream != null) {
      return _weekStream!;
    }
    _cachedWeekStart = _weekStart;
    _weekStream = widget.eventService.streamEventsForWeek(_weekStart);
    return _weekStream!;
  }

  bool _isToday(DateTime date) => _dateOnly(date) == _dateOnly(DateTime.now());

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.year != end.year) {
      return '${_monthNames[_weekStart.month - 1]} ${_weekStart.day}, '
          '${_weekStart.year} – ${_monthNames[end.month - 1]} ${end.day}, ${end.year}';
    }
    if (_weekStart.month == end.month) {
      return '${_monthNames[_weekStart.month - 1]} '
          '${_weekStart.day}–${end.day}, ${end.year}';
    }
    return '${_monthNames[_weekStart.month - 1]} ${_weekStart.day} – '
        '${_monthNames[end.month - 1]} ${end.day}, ${end.year}';
  }

  TimeOfDay _defaultEndFor(TimeOfDay start) =>
      minutesToTimeOfDay(resolveEndMinutes(timeToMinutes(start), null));

  Future<void> _addEvent(DateTime date) async {
    final now = TimeOfDay.now();
    final draft = await _showEventEditor(
      title: 'Add to ${_dayNames[date.weekday - 1]}',
      initialDay: date,
      initialTitle: '',
      initialLocation: '',
      initialTime: now,
      initialEndTime: _defaultEndFor(now),
      initialSubjectId: ShellScope.maybeOf(context)?.subjectId,
      allowRepeatToggle: true,
      initialRepeatWeekly: false,
      confirmLabel: 'Add',
    );
    if (draft == null || draft.title.isEmpty) return;

    if (draft.repeatWeekly) {
      await widget.eventService.addRecurringEvent(
        weekday: draft.day.weekday,
        title: draft.title,
        time: draft.time,
        endTime: draft.endTime,
        location: draft.location,
        subjectId: draft.subjectId,
      );
    } else {
      await widget.eventService.addEvent(
        day: draft.day,
        title: draft.title,
        time: draft.time,
        endTime: draft.endTime,
        location: draft.location,
        subjectId: draft.subjectId,
      );
    }
  }

  Future<void> _openEvent(AppEvent event) async {
    final day = _dayFromKey(event.dayKey);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final location = event.location?.trim();
        final range = formatTimeRange(
          context,
          event.startMinutes,
          event.endMinutes,
        );
        final duration = formatDurationLabel(
          event.startMinutes,
          event.endMinutes,
        );
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.schedule,
                label: '$range  ·  $duration',
              ),
              _InfoRow(
                icon: Icons.calendar_today,
                label:
                    '${_dayNames[day.weekday - 1]}  •  ${day.day}/${day.month}/${day.year}',
              ),
              if (location != null && location.isNotEmpty)
                _InfoRow(icon: Icons.place_outlined, label: location),
              if (event.isRecurring)
                _InfoRow(icon: Icons.repeat, label: 'Repeats every week'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _editEvent(event);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteEvent(event);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap outside to close',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editEvent(AppEvent event) async {
    final day = _dayFromKey(event.dayKey);
    final draft = await _showEventEditor(
      title: 'Edit event',
      initialDay: day,
      initialTitle: event.title,
      initialLocation: event.location ?? '',
      initialTime: event.start,
      initialEndTime: event.end,
      initialSubjectId: event.subjectId,
      allowRepeatToggle: false,
      initialRepeatWeekly: event.isRecurring,
      confirmLabel: 'Save',
    );
    if (draft == null || draft.title.isEmpty) return;

    await widget.eventService.updateEventOrRecurring(
      event: event,
      day: draft.day,
      title: draft.title,
      time: draft.time,
      endTime: draft.endTime,
      location: draft.location,
      subjectId: draft.subjectId,
    );
  }

  Future<_EventDraft?> _showEventEditor({
    required String title,
    required DateTime initialDay,
    required String initialTitle,
    required String initialLocation,
    required TimeOfDay initialTime,
    required TimeOfDay initialEndTime,
    required String? initialSubjectId,
    required bool allowRepeatToggle,
    required bool initialRepeatWeekly,
    required String confirmLabel,
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final locationController = TextEditingController(text: initialLocation);
    var time = initialTime;
    var endTime = initialEndTime;
    var day = initialDay;
    var repeatWeekly = initialRepeatWeekly;
    String? subjectId = initialSubjectId;

    void ensureEndAfterStart(void Function(void Function()) setDialogState) {
      final startMins = timeToMinutes(time);
      final endMins = timeToMinutes(endTime);
      if (endMins <= startMins) {
        setDialogState(() {
          endTime = minutesToTimeOfDay(resolveEndMinutes(startMins, null));
        });
      }
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Event',
                    hintText: 'Lecture, study session…',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey(subjectId),
                  initialValue: subjectId != null &&
                          _subjects.any((s) => s.id == subjectId)
                      ? subjectId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._subjects.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => subjectId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: const Text('Start'),
                  subtitle: Text(time.format(context)),
                  trailing: TextButton(
                    onPressed: () async {
                      final chosen = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (chosen != null) {
                        setDialogState(() => time = chosen);
                        ensureEndAfterStart(setDialogState);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop_outlined),
                  title: const Text('End'),
                  subtitle: Text(endTime.format(context)),
                  trailing: TextButton(
                    onPressed: () async {
                      final chosen = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (chosen != null) {
                        setDialogState(() => endTime = chosen);
                        ensureEndAfterStart(setDialogState);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('${day.day}/${day.month}/${day.year}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (chosen != null) {
                        setDialogState(() => day = chosen);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                if (allowRepeatToggle)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: repeatWeekly,
                    title: const Text('Repeat every week'),
                    onChanged: (value) =>
                        setDialogState(() => repeatWeekly = value ?? false),
                  ),
                if (!allowRepeatToggle && initialRepeatWeekly)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.repeat),
                    title: Text('Weekly class — edits apply to every week'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );

    final resultTitle = titleController.text.trim();
    final resultLocation = locationController.text.trim();
    titleController.dispose();
    locationController.dispose();
    if (shouldSave != true) return null;

    final startMins = timeToMinutes(time);
    final resolvedEnd = minutesToTimeOfDay(
      resolveEndMinutes(startMins, timeToMinutes(endTime)),
    );

    return _EventDraft(
      day: day,
      title: resultTitle,
      time: time,
      endTime: resolvedEnd,
      location: resultLocation.isEmpty ? null : resultLocation,
      repeatWeekly: repeatWeekly,
      subjectId: subjectId,
    );
  }

  Future<void> _deleteEvent(AppEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          event.isRecurring
              ? 'This will remove the event from every week.'
              : 'This event will be permanently removed.',
        ),
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
    if (confirmed == true) {
      await widget.eventService.deleteEventOrRecurring(event.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Subject>>(
      stream: _subjectsStream,
      builder: (context, subjectSnap) {
        _subjects = subjectSnap.data ?? const <Subject>[];
        final byId = _subjectsById;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FrostPanel(
              opacity: widget.panelOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(scheme),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<Map<String, List<AppEvent>>>(
                      stream: _eventsForWeek(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Could not load this week: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final grouped =
                            snapshot.data ?? const <String, List<AppEvent>>{};
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final separators = 10.0 * 6;
                            final fitted =
                                (constraints.maxWidth - separators) / 7;
                            if (fitted >= 96) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var index = 0;
                                      index < dates.length;
                                      index++) ...[
                                    if (index > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: _DayColumn(
                                        date: dates[index],
                                        dayName: _dayNames[index],
                                        isToday: _isToday(dates[index]),
                                        events: grouped[dayKey(dates[index])] ??
                                            const [],
                                        subjectsById: byId,
                                        pxPerMinute: _pxPerMinute,
                                        minBlockHeight: _minBlockHeight,
                                        defaultStartMinutes:
                                            _defaultStartMinutes,
                                        defaultEndMinutes: _defaultEndMinutes,
                                        rangePaddingMinutes:
                                            _rangePaddingMinutes,
                                        onAdd: () => _addEvent(dates[index]),
                                        onOpen: _openEvent,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }
                            final columnWidth = math.max(120.0, fitted);
                            return Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: dates.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final date = dates[index];
                                  return SizedBox(
                                    width: columnWidth,
                                    child: _DayColumn(
                                      date: date,
                                      dayName: _dayNames[index],
                                      isToday: _isToday(date),
                                      events:
                                          grouped[dayKey(date)] ?? const [],
                                      subjectsById: byId,
                                      pxPerMinute: _pxPerMinute,
                                      minBlockHeight: _minBlockHeight,
                                      defaultStartMinutes:
                                          _defaultStartMinutes,
                                      defaultEndMinutes: _defaultEndMinutes,
                                      rangePaddingMinutes:
                                          _rangePaddingMinutes,
                                      onAdd: () => _addEvent(date),
                                      onOpen: _openEvent,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    final isNarrow = MediaQuery.of(context).size.width < 900;
    final isCurrentWeek =
        _weekStart == _startOfWeek(DateTime.now());

    if (isNarrow) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isCurrentWeek
                  ? null
                  : () => setState(() {
                        _weekStart = _startOfWeek(DateTime.now());
                      }),
              child: Text(
                isCurrentWeek ? 'This week' : _weekLabel(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous week',
            onPressed: () => setState(() {
              _weekStart = _weekStart.subtract(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Next week',
            onPressed: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            _weekLabel(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.90)),
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() {
            _weekStart = _startOfWeek(DateTime.now());
          }),
          icon: const Icon(Icons.today, size: 18),
          label: const Text('This week'),
        ),
        IconButton(
          tooltip: 'Previous week',
          onPressed: () => setState(() {
            _weekStart = _weekStart.subtract(const Duration(days: 7));
          }),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: () => setState(() {
            _weekStart = _weekStart.add(const Duration(days: 7));
          }),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.day,
    required this.title,
    required this.time,
    required this.endTime,
    required this.location,
    required this.repeatWeekly,
    required this.subjectId,
  });

  final DateTime day;
  final String title;
  final TimeOfDay time;
  final TimeOfDay endTime;
  final String? location;
  final bool repeatWeekly;
  final String? subjectId;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _OverlapSlot {
  const _OverlapSlot({
    required this.event,
    required this.column,
    required this.columnCount,
  });

  final AppEvent event;
  final int column;
  final int columnCount;
}

/// Pack overlapping events into side-by-side columns (calendar-style).
List<_OverlapSlot> _placeOverlapping(List<AppEvent> events) {
  if (events.isEmpty) return const [];
  final sorted = [...events]
    ..sort((a, b) {
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      if (byStart != 0) return byStart;
      return a.endMinutes.compareTo(b.endMinutes);
    });

  final cluster = <({AppEvent event, int column})>[];
  final columnEnds = <int>[];
  var clusterEnd = -1;
  final out = <_OverlapSlot>[];

  void flush() {
    if (cluster.isEmpty) return;
    final cols = cluster.fold<int>(1, (m, e) => math.max(m, e.column + 1));
    for (final item in cluster) {
      out.add(
        _OverlapSlot(
          event: item.event,
          column: item.column,
          columnCount: cols,
        ),
      );
    }
    cluster.clear();
    columnEnds.clear();
  }

  for (final event in sorted) {
    if (cluster.isNotEmpty && event.startMinutes >= clusterEnd) {
      flush();
      clusterEnd = -1;
    }
    var col = 0;
    while (col < columnEnds.length && columnEnds[col] > event.startMinutes) {
      col++;
    }
    if (col == columnEnds.length) {
      columnEnds.add(event.endMinutes);
    } else {
      columnEnds[col] = event.endMinutes;
    }
    cluster.add((event: event, column: col));
    clusterEnd = math.max(clusterEnd, event.endMinutes);
  }
  flush();
  return out;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.dayName,
    required this.isToday,
    required this.events,
    required this.subjectsById,
    required this.pxPerMinute,
    required this.minBlockHeight,
    required this.defaultStartMinutes,
    required this.defaultEndMinutes,
    required this.rangePaddingMinutes,
    required this.onAdd,
    required this.onOpen,
  });

  final DateTime date;
  final String dayName;
  final bool isToday;
  final List<AppEvent> events;
  final Map<String, Subject> subjectsById;
  final double pxPerMinute;
  final double minBlockHeight;
  final int defaultStartMinutes;
  final int defaultEndMinutes;
  final int rangePaddingMinutes;
  final VoidCallback onAdd;
  final ValueChanged<AppEvent> onOpen;

  (int, int) _visibleRange() {
    var start = defaultStartMinutes;
    var end = defaultEndMinutes;
    if (events.isNotEmpty) {
      start = events.map((e) => e.startMinutes).reduce(math.min);
      end = events.map((e) => e.endMinutes).reduce(math.max);
      start = math.min(start, defaultStartMinutes);
      end = math.max(end, defaultEndMinutes);
      start = (start - rangePaddingMinutes).clamp(0, 24 * 60);
      end = (end + rangePaddingMinutes).clamp(0, 24 * 60);
    }
    if (end <= start) end = start + 60;
    // Snap to whole hours for cleaner hour lines
    start = (start ~/ 60) * 60;
    end = ((end + 59) ~/ 60) * 60;
    if (end <= start) end = start + 60;
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (rangeStart, rangeEnd) = _visibleRange();
    final gridHeight = (rangeEnd - rangeStart) * pxPerMinute;

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? scheme.primary.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? scheme.primary : scheme.outline.withValues(alpha: 0.35),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName.substring(0, 3).toUpperCase(),
                        style: TextStyle(
                          color: isToday
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.88),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add event',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline, size: 21),
                ),
              ],
            ),
          ),
          Divider(color: scheme.outline.withValues(alpha: 0.25), height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
              child: SizedBox(
                height: gridHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slots = _placeOverlapping(events);
                    final columns = slots.fold<int>(
                      1,
                      (m, s) => math.max(m, s.columnCount),
                    );
                    final widthEach = (constraints.maxWidth - 44) / columns;
                    return Stack(
                      children: [
                        ..._hourLines(context, rangeStart, rangeEnd),
                        if (events.isEmpty)
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                isToday ? 'Your day is clear' : 'No events',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.86),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ...slots.map((slot) {
                          final event = slot.event;
                          final top = (event.startMinutes - rangeStart) *
                              pxPerMinute;
                          final naturalHeight =
                              (event.endMinutes - event.startMinutes) *
                                  pxPerMinute;
                          final height = math.max(22.0, naturalHeight);
                          return Positioned(
                            top: top,
                            left: 44 + slot.column * widthEach + 1,
                            width: math.max(12.0, widthEach - 2),
                            height: height,
                            child: _WeeklyEventCard(
                              event: event,
                              height: height,
                              subjectColor: event.subjectId != null
                                  ? subjectsById[event.subjectId!]?.color
                                  : null,
                              onTap: () => onOpen(event),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _hourLines(BuildContext context, int rangeStart, int rangeEnd) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <Widget>[];
    for (var m = rangeStart; m <= rangeEnd; m += 60) {
      final top = (m - rangeStart) * pxPerMinute;
      final label = minutesToTimeOfDay(m.clamp(0, 24 * 60 - 1)).format(context);
      lines.add(
        Positioned(
          top: top - 6,
          left: 0,
          right: 0,
          height: 12,
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.86),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return lines;
  }
}

class _WeeklyEventCard extends StatelessWidget {
  const _WeeklyEventCard({
    required this.event,
    required this.height,
    required this.onTap,
    this.subjectColor,
  });

  final AppEvent event;
  final double height;
  final VoidCallback onTap;
  final Color? subjectColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = subjectColor ?? scheme.primary;
    final location = event.location?.trim();
    final range = formatTimeRange(
      context,
      event.startMinutes,
      event.endMinutes,
    );
    final showTime = height >= 44;
    final showLocation = height >= 70 &&
        location != null &&
        location.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8,
            height < 44 ? 4 : 6,
            8,
            height < 44 ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(9),
            border: Border(
              left: BorderSide(
                color: accent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTime)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        range,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (event.isRecurring)
                      Icon(
                        Icons.repeat,
                        size: 11,
                        color: scheme.onSurface.withValues(alpha: 0.86),
                      ),
                  ],
                ),
              if (showTime) const SizedBox(height: 2),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: height < 50 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: height < 44 ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (showLocation)
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
