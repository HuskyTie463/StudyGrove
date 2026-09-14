import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../pages/lecture_summary_page.dart';
import '../services/assessment_attachment_store.dart';
import '../services/lecture_lab_service.dart';
import '../services/note_service.dart';
import '../theme/design_tokens.dart';
import 'math_text.dart';
import 'sg_primitives.dart';

class PendingAssessmentMaterial {
  PendingAssessmentMaterial({
    required this.attachment,
    this.sourcePath,
    this.bytes,
  });

  final AssessmentAttachment attachment;
  final String? sourcePath;
  final List<int>? bytes;

  bool get needsUpload =>
      attachment.isFile &&
      (bytes != null && bytes!.isNotEmpty ||
          (sourcePath != null && sourcePath!.trim().isNotEmpty));
}

class AssessmentMaterialsActions extends StatelessWidget {
  const AssessmentMaterialsActions({
    super.key,
    required this.onUpload,
    required this.onPickExisting,
    this.busy = false,
  });

  final VoidCallback? onUpload;
  final VoidCallback? onPickExisting;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SgSecondaryButton(
          label: busy ? 'Adding…' : 'Upload files',
          icon: Icons.upload_file_outlined,
          onPressed: busy ? null : onUpload,
        ),
        SgSecondaryButton(
          label: 'Pick lectures / files',
          icon: Icons.library_add_outlined,
          onPressed: busy ? null : onPickExisting,
        ),
      ],
    );
  }
}

class AssessmentAttachmentList extends StatelessWidget {
  const AssessmentAttachmentList({
    super.key,
    required this.attachments,
    required this.onOpen,
    required this.onRemove,
  });

  final List<AssessmentAttachment> attachments;
  final void Function(AssessmentAttachment att) onOpen;
  final void Function(AssessmentAttachment att) onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return Column(
      children: [
        for (final att in attachments)
          Padding(
            padding: EdgeInsets.only(top: t.gap(1)),
            child: Material(
              color: t.bgMuted.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(t.radiusMd),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(_iconFor(att), color: t.decorationAccent),
                title: MathText(att.name),
                subtitle: Text(
                  att.kind.label,
                  style: TextStyle(color: t.textMuted, fontSize: 12),
                ),
                onTap: () => onOpen(att),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemove(att),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AssessmentPendingChips extends StatelessWidget {
  const AssessmentPendingChips({
    super.key,
    required this.pending,
    required this.onRemove,
  });

  final List<PendingAssessmentMaterial> pending;
  final void Function(PendingAssessmentMaterial item) onRemove;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in pending)
          InputChip(
            avatar: Icon(_iconFor(item.attachment), size: 16),
            label: Text(item.attachment.name),
            onDeleted: () => onRemove(item),
          ),
      ],
    );
  }
}

IconData _iconFor(AssessmentAttachment att) {
  if (att.isLecture) return Icons.menu_book_outlined;
  if (att.isNote) return Icons.sticky_note_2_outlined;
  if (att.isImage) return Icons.image_outlined;
  return Icons.insert_drive_file_outlined;
}

Future<List<PendingAssessmentMaterial>> pickAssessmentUploads() async {
  final picked = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
  );
  if (picked == null) return const [];
  final out = <PendingAssessmentMaterial>[];
  for (final f in picked.files) {
    final name = (f.name).trim();
    if (name.isEmpty && (f.path ?? '').isEmpty) continue;
    final filename = name.isEmpty
        ? AssessmentAttachment.basename(f.path ?? 'file')
        : name;
    final bytes = f.bytes;
    out.add(
      PendingAssessmentMaterial(
        attachment: AssessmentAttachment(
          id: AssessmentAttachment.newId(),
          kind: AssessmentAttachmentKind.file,
          name: filename,
          absolutePath: f.path,
        ),
        sourcePath: f.path,
        bytes: bytes == null || bytes.isEmpty ? null : bytes,
      ),
    );
  }
  return out;
}

Future<List<AssessmentAttachment>> showAssessmentLibraryPicker({
  required BuildContext context,
  required List<LectureNote> lectures,
  required List<NoteItem> notes,
  required List<AssessmentAttachment> libraryFiles,
  required Set<String> alreadyLinked,
}) async {
  final t = DesignTokens.of(context);
  final selected = <String>{};
  final byKey = <String, AssessmentAttachment>{};

  void consider(AssessmentAttachment att) {
    if (alreadyLinked.contains(att.linkKey)) return;
    byKey.putIfAbsent(att.linkKey, () => att);
  }

  for (final lecture in lectures) {
    consider(
      AssessmentAttachment(
        id: AssessmentAttachment.newId(),
        kind: AssessmentAttachmentKind.lecture,
        name: lecture.title,
        lectureId: lecture.id,
      ),
    );
  }
  for (final note in notes) {
    consider(
      AssessmentAttachment(
        id: AssessmentAttachment.newId(),
        kind: AssessmentAttachmentKind.note,
        name: note.title.trim().isEmpty ? 'Note' : note.title.trim(),
        noteId: note.id,
      ),
    );
  }
  for (final file in libraryFiles) {
    if (!file.isFile) continue;
    consider(file);
  }

  final lecturesOnly =
      byKey.values.where((e) => e.isLecture).toList(growable: false);
  final notesOnly = byKey.values.where((e) => e.isNote).toList(growable: false);
  final filesOnly = byKey.values.where((e) => e.isFile).toList(growable: false);

  if (lecturesOnly.isEmpty && notesOnly.isEmpty && filesOnly.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved lectures or files to pick yet.'),
        ),
      );
    }
    return const [];
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget section(String title, List<AssessmentAttachment> items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                for (final att in items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(att.linkKey),
                    secondary: Icon(_iconFor(att)),
                    title: MathText(att.name),
                    subtitle: Text(
                      att.kind.label,
                      style: TextStyle(color: t.textMuted, fontSize: 12),
                    ),
                    onChanged: (v) {
                      setLocal(() {
                        if (v == true) {
                          selected.add(att.linkKey);
                        } else {
                          selected.remove(att.linkKey);
                        }
                      });
                    },
                  ),
              ],
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick lectures / files',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  SizedBox(height: t.gap(0.5)),
                  Text(
                    'Links what you already have — lectures stay in Lecture Lab.',
                    style: TextStyle(color: t.textMuted, fontSize: 13),
                  ),
                  SizedBox(height: t.gap(1.5)),
                  Expanded(
                    child: ListView(
                      children: [
                        section('Lectures', lecturesOnly),
                        section('Notes', notesOnly),
                        section('Files already in Study Grove', filesOnly),
                      ],
                    ),
                  ),
                  SizedBox(height: t.gap(1)),
                  SgPrimaryButton(
                    label: selected.isEmpty
                        ? 'Add'
                        : 'Add (${selected.length})',
                    expanded: true,
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  if (ok != true) return const [];
  return [
    for (final key in selected)
      if (byKey[key] != null) byKey[key]!,
  ];
}

Future<void> openAssessmentAttachment({
  required BuildContext context,
  required AssessmentAttachment att,
  LectureLabService? lectureLab,
  NoteService? notes,
}) async {
  if (att.isLecture) {
    final id = att.lectureId;
    if (id == null || lectureLab == null) return;
    final lecture = await lectureLab.getLecture(id);
    if (!context.mounted) return;
    if (lecture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That lecture is no longer saved.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LectureSummaryPage(
          lecture: lecture,
          service: lectureLab,
        ),
      ),
    );
    return;
  }

  if (att.isNote) {
    final id = att.noteId;
    if (id == null || notes == null) return;
    final note = await notes.getNote(id);
    if (!context.mounted) return;
    if (note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That note is no longer saved.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: MathText(note.title.trim().isEmpty ? 'Note' : note.title),
        content: SingleChildScrollView(
          child: MathText(
            note.body.trim().isEmpty ? 'Empty note.' : note.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  File? file;
  try {
    file = await AssessmentAttachmentStore.resolve(att);
  } catch (_) {}
  if (file == null || !file.existsSync()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That file is only on the device where it was uploaded.',
          ),
        ),
      );
    }
    return;
  }
  if (att.isImage && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(att.name)),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.file(file!, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }
  final uri = Uri.file(file.absolute.path);
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${att.name}.')),
    );
  }
}

List<AssessmentAttachment> libraryFilesFrom(List<Assessment> assessments) {
  final seen = <String>{};
  final out = <AssessmentAttachment>[];
  for (final a in assessments) {
    for (final att in a.attachments) {
      if (!att.isFile) continue;
      if (seen.add(att.linkKey)) out.add(att);
    }
  }
  return out;
}
