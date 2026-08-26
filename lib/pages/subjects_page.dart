import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/event_service.dart';
import '../services/subject_service.dart';
import '../services/timetable_import.dart';
import '../ui/shared_ui.dart';
import '../utils/datetime_utils.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({
    super.key,
    required this.panelOpacity,
    required this.subjectService,
    required this.eventService,
  });

  final double panelOpacity;
  final SubjectService subjectService;
  final EventService eventService;

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  late final Stream<List<Subject>> _subjectsStream;

  static const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _subjectsStream = widget.subjectService.streamSubjects();
  }

  Future<void> _promptSubject({Subject? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    var colorValue = existing?.colorValue ?? kSubjectColorPalette.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add subject' : 'Edit subject'),
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
                    hintText: 'e.g., Calculus',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code (optional)',
                    hintText: 'e.g., MATH101',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Colour',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.88),
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
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim();
    nameCtrl.dispose();
    codeCtrl.dispose();
    if (ok != true || name.isEmpty) return;

    if (existing == null) {
      await widget.subjectService.addSubject(
        name: name,
        code: code.isEmpty ? null : code,
        colorValue: colorValue,
      );
    } else {
      await widget.subjectService.updateSubject(
        id: existing.id,
        name: name,
        code: code.isEmpty ? null : code,
        colorValue: colorValue,
      );
    }
  }

  Future<void> _confirmDelete(Subject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          'Remove "${subject.label}"? Events keep their times — only the subject tag is gone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.subjectService.deleteSubject(subject.id);
    }
  }

  Future<void> _openImportDialog(List<Subject> subjects) async {
    final pasteCtrl = TextEditingController();
    List<TimetableEventDraft>? drafts;
    List<String?> selectedSubjectIds = [];

    final imported = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Import timetable'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste one class per line. Examples:',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        'Mon 9:00-10:00 MATH101 Tutorial Room 204\n'
                        'Mon 9:00 – 10:30 Physics Lecture | Hall A\n'
                        'Wed 2pm CHEM Lab @ Building 12',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.80),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pasteCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Timetable text',
                        alignLabelWithHint: true,
                        hintText: 'Paste here…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftButton(
                      label: 'Preview',
                      icon: Icons.preview_outlined,
                      onPressed: () {
                        final parsed =
                            TimetableImportParser.parse(pasteCtrl.text);
                        setDialogState(() {
                          drafts = parsed;
                          selectedSubjectIds = parsed.map((d) {
                            final match = widget.subjectService
                                .matchHint(subjects, d.subjectHint ?? d.title);
                            return match?.id;
                          }).toList();
                        });
                      },
                    ),
                    if (drafts != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        drafts!.isEmpty
                            ? 'No rows recognised.'
                            : '${drafts!.length} class${drafts!.length == 1 ? '' : 'es'} found',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < drafts!.length; i++) ...[
                        _ImportPreviewRow(
                          draft: drafts![i],
                          dayLabel: _dayShort[drafts![i].weekday - 1],
                          subjects: subjects,
                          selectedSubjectId: selectedSubjectIds[i],
                          onSubjectChanged: (id) => setDialogState(
                            () => selectedSubjectIds[i] = id,
                          ),
                        ),
                        if (i < drafts!.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: drafts == null || drafts!.isEmpty
                    ? null
                    : () async {
                        final items = <
                            ({
                              int weekday,
                              String title,
                              TimeOfDay time,
                              TimeOfDay? endTime,
                              String? location,
                              String? subjectId
                            })>[];
                        for (var i = 0; i < drafts!.length; i++) {
                          final d = drafts![i];
                          items.add((
                            weekday: d.weekday,
                            title: d.title,
                            time: d.time,
                            endTime: d.endTime,
                            location: d.location,
                            subjectId: selectedSubjectIds[i],
                          ));
                        }
                        await widget.eventService
                            .addRecurringEventsBatch(items);
                        if (ctx.mounted) Navigator.pop(ctx, items.length);
                      },
                child: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );

    pasteCtrl.dispose();
    if (imported != null && imported > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported weekly event${imported == 1 ? '' : 's'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FrostPanel(
          opacity: widget.panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Subjects',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add subject',
                    onPressed: () => _promptSubject(),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SoftButton(
                label: 'Import timetable',
                icon: Icons.upload_file_outlined,
                filled: true,
                onPressed: () async {
                  final subjects =
                      await widget.subjectService.streamSubjects().first;
                  if (!mounted) return;
                  await _openImportDialog(subjects);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Subject>>(
                  stream: _subjectsStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load subjects: ${snap.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.84),
                          ),
                        ),
                      );
                    }
                    final subjects = snap.data ?? const <Subject>[];
                    if (subjects.isEmpty) {
                      return Center(
                        child: Text(
                          'No subjects yet.\nAdd one or import a timetable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.84),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: subjects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = subjects[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scheme.outline.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.outline
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (s.code != null &&
                                        s.code!.trim().isNotEmpty)
                                      Text(
                                        s.code!,
                                        style: TextStyle(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.65),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _promptSubject(existing: s),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(s),
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.65),
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
        ),
      ),
    );
  }
}

class _ImportPreviewRow extends StatelessWidget {
  const _ImportPreviewRow({
    required this.draft,
    required this.dayLabel,
    required this.subjects,
    required this.selectedSubjectId,
    required this.onSubjectChanged,
  });

  final TimetableEventDraft draft;
  final String dayLabel;
  final List<Subject> subjects;
  final String? selectedSubjectId;
  final ValueChanged<String?> onSubjectChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = formatTimeRange(
      context,
      timeToMinutes(draft.time),
      timeToMinutes(draft.endTime),
    );
    final loc = draft.location?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$dayLabel  $time  ·  ${draft.title}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (loc != null && loc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              loc,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.88),
                fontSize: 12,
              ),
            ),
          ],
          if (draft.subjectHint != null) ...[
            const SizedBox(height: 4),
            Text(
              'Hint: ${draft.subjectHint}',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.88),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: ValueKey(selectedSubjectId),
            initialValue: selectedSubjectId != null &&
                    subjects.any((s) => s.id == selectedSubjectId)
                ? selectedSubjectId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Subject',
              isDense: true,
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
            onChanged: onSubjectChanged,
          ),
        ],
      ),
    );
  }
}
