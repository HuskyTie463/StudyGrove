import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/note_service.dart';
import '../ui/math_text.dart';
import '../ui/shared_ui.dart';
import '../ui/shell_nav.dart';
import '../ui/shell_scope.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({
    super.key,
    required this.panelOpacity,
    required this.noteService,
  });

  final double panelOpacity;
  final NoteService noteService;

  Future<void> _edit(BuildContext context, {NoteItem? existing}) async {
    final scopedId =
        existing?.subjectId ?? ShellScope.maybeOf(context)?.subjectId;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New note' : 'Edit note'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(ctx).width - 48).clamp(240.0, 480.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Week 4 lecture questions',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  minLines: 6,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                    hintText: 'Write anything you want to keep.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    await noteService.upsert(
      id: existing?.id,
      title: title.isEmpty ? 'Untitled' : title,
      body: body,
      subjectId: scopedId,
    );
  }

  Future<void> _copyTimetableLink(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: kTimetableAccessLink),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FrostPanel(
          opacity: panelOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tooltip(
                    message: 'Copy a link that opens your timetable',
                    child: TextButton.icon(
                      onPressed: () => _copyTimetableLink(context),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Copy link'),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Add note',
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: StreamBuilder<List<NoteItem>>(
                  stream: noteService.streamNotes(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const <NoteItem>[];
                    final scope = ShellScope.maybeOf(context);
                    final notes = all
                        .where(
                          (n) => matchesSelectedSubject(
                            selectedId: scope?.subjectId,
                            subjects: scope?.subjects ?? const [],
                            itemSubjectId: n.subjectId,
                            title: n.title,
                          ),
                        )
                        .toList();
                    if (notes.isEmpty) {
                      return Text(
                        'No notes yet. Tap + to add one.',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.84),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final n = notes[i];
                        return Material(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _edit(context, existing: n),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MathText(
                                          n.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (n.body.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 72,
                                            ),
                                            child: ClipRect(
                                              child: MathText(
                                                n.body,
                                                style: TextStyle(
                                                  color: scheme.onSurface
                                                      .withValues(alpha: 0.82),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => noteService.delete(n.id),
                                    icon: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
