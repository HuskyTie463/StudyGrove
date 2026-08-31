import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/event_service.dart';
import '../services/task_service.dart';
import '../ui/shared_ui.dart';
import '../ui/shell_scope.dart';
import '../utils/datetime_utils.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({
    super.key,
    required this.panelOpacity,
    required this.tasks,
    required this.onToggleTask,
    required this.onAddTask,
    required this.onRemoveTask,
    required this.onSetUrgency,
    required this.eventService,
    required this.taskService,
  });

  final double panelOpacity;
  final List<TaskItem> tasks;

  final void Function(int index) onToggleTask;
  final VoidCallback onAddTask;
  final void Function(int index) onRemoveTask;
  final void Function(int index, TaskUrgency urgency) onSetUrgency;

  final EventService eventService;
  final TaskService taskService;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime selectedDay = DateTime.now();
  DateTime? _cachedStreamDay;
  Stream<List<AppEvent>>? _eventsStream;

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

  Future<bool> _confirm(BuildContext context, String msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _promptAddEvent(BuildContext context) async {
    final scopedSubject = ShellScope.maybeOf(context)?.subjectId;
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    TimeOfDay pickedTime = TimeOfDay.now();
    TimeOfDay pickedEnd = minutesToTimeOfDay(
      resolveEndMinutes(timeToMinutes(pickedTime), null),
    );
    bool repeatWeekly = false;

    void ensureEndAfterStart(void Function(void Function()) setDialogState) {
      final startMins = timeToMinutes(pickedTime);
      if (timeToMinutes(pickedEnd) <= startMins) {
        setDialogState(() {
          pickedEnd = minutesToTimeOfDay(resolveEndMinutes(startMins, null));
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
                TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(hintText: "e.g., Library study block")),
                const SizedBox(height: 10),
                TextField(controller: locCtrl, decoration: const InputDecoration(hintText: "Location (optional)")),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GreenChip("Start: ${pickedTime.format(ctx)}"),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: pickedTime);
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
                        final t = await showTimePicker(context: ctx, initialTime: pickedEnd);
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
                  title: const Text("Repeat weekly (e.g. timetable class)", style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF1C6E52),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Add")),
          ],
        ),
      ),
    );

    final title = titleCtrl.text.trim();
    final loc = locCtrl.text.trim();
    titleCtrl.dispose();
    locCtrl.dispose();

    if (ok == true && title.isNotEmpty) {
      final endTime = minutesToTimeOfDay(
        resolveEndMinutes(timeToMinutes(pickedTime), timeToMinutes(pickedEnd)),
      );
      if (repeatWeekly) {
        await widget.eventService.addRecurringEvent(
          weekday: selectedDay.weekday,
          title: title,
          time: pickedTime,
          endTime: endTime,
          location: loc.isEmpty ? null : loc,
          subjectId: scopedSubject,
        );
      } else {
        await widget.eventService.addEvent(
          day: _dayKey(selectedDay),
          title: title,
          time: pickedTime,
          endTime: endTime,
          location: loc.isEmpty ? null : loc,
          subjectId: scopedSubject,
        );
      }
      if (mounted) setState(() {});
    }
  }

  String _formatDate(DateTime d) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 900;

    Widget tasksPanel() => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Tasks", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: widget.onAddTask, icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: widget.tasks.isEmpty
                    ? Text("No tasks yet.", style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.84)))
                    : ListView.separated(
                        itemCount: widget.tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = widget.tasks[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: scheme.outline.withValues(alpha: 0.30)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(value: t.done, onChanged: (_) => widget.onToggleTask(i)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: t.done
                                              ? scheme.onSurface.withValues(alpha: 0.86)
                                              : scheme.onSurface,
                                          decoration: t.done ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      if (t.isUrgent)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Urgent',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.error,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: t.isUrgent
                                      ? 'Urgent — tap for normal'
                                      : 'Normal — tap for urgent',
                                  onPressed: () => widget.onSetUrgency(
                                    i,
                                    t.isUrgent
                                        ? TaskUrgency.normal
                                        : TaskUrgency.urgent,
                                  ),
                                  icon: Icon(
                                    t.isUrgent
                                        ? Icons.priority_high
                                        : Icons.low_priority,
                                    size: 20,
                                    color: t.isUrgent
                                        ? scheme.error
                                        : scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                // X delete button for tasks
                                IconButton(
                                  tooltip: "Delete",
                                  onPressed: () => widget.onRemoveTask(i),
                                  icon: Icon(Icons.close, size: 20, color: scheme.onSurface.withValues(alpha: 0.84)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );

    Widget schedulePanel() => FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StreamBuilder<List<AppEvent>>(
                  stream: _getEventsStream(selectedDay),
                  builder: (context, snap) {
                    final scope = ShellScope.maybeOf(context);
                    final events = List<AppEvent>.from(snap.data ?? const <AppEvent>[])
                        .where(
                          (e) => matchesSelectedSubject(
                            selectedId: scope?.subjectId,
                            subjects: scope?.subjects ?? const [],
                            itemSubjectId: e.subjectId,
                            title: e.title,
                          ),
                        )
                        .toList()
                      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Schedule",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _promptAddEvent(context),
                              icon: const Icon(Icons.add_alarm),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: snap.connectionState ==
                                      ConnectionState.waiting &&
                                  !snap.hasData
                              ? const Center(child: CircularProgressIndicator())
                              : events.isEmpty
                                  ? Text(
                                      "No events for this day.",
                                      style: TextStyle(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.72),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: events.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, i) {
                                        final e = events[i];
                                        final time = formatTimeRange(
                                          context,
                                          e.startMinutes,
                                          e.endMinutes,
                                        );

                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: scheme.primary
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: scheme.outline
                                                  .withValues(alpha: 0.30),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                time,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              if (e.isRecurring)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 6),
                                                  child: Icon(
                                                    Icons.repeat,
                                                    size: 14,
                                                    color: scheme.onSurface
                                                        .withValues(
                                                            alpha: 0.72),
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  (e.location == null ||
                                                          e.location!
                                                              .trim()
                                                              .isEmpty)
                                                      ? e.title
                                                      : "${e.title} • ${e.location}",
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: scheme.onSurface,
                                                  ),
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
                                                      .deleteEventOrRecurring(
                                                          e.id);
                                                  if (mounted) setState(() {});
                                                },
                                                icon: Icon(
                                                  Icons.close,
                                                  size: 20,
                                                  color: scheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daily Planner",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GreenChip(_formatDate(selectedDay)),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDay,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => selectedDay = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text("Pick date"),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: tasksPanel()),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: schedulePanel()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 420, child: tasksPanel()),
                          const SizedBox(height: 14),
                          SizedBox(height: 380, child: schedulePanel()),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}