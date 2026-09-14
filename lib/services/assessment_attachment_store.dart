import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Copies uploaded assessment files into app support so they survive restarts.
class AssessmentAttachmentStore {
  static const folderName = 'assessment_files';

  static String sanitizeFilename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'file';
    final cleaned = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  static String relativePathFor({
    required String uid,
    required String assessmentId,
    required String attachmentId,
    required String filename,
  }) {
    return '$folderName/$uid/$assessmentId/'
        '${attachmentId}_${sanitizeFilename(filename)}';
  }

  static File resolveIn(Directory root, AssessmentAttachment att) {
    final rel = (att.relativePath ?? '').trim();
    if (rel.isNotEmpty) {
      return File('${root.path}${Platform.pathSeparator}'
          '${rel.replaceAll('/', Platform.pathSeparator)}');
    }
    final abs = (att.absolutePath ?? '').trim();
    return File(abs);
  }

  static Future<Directory> appRoot() => getApplicationSupportDirectory();

  static Future<File> resolve(AssessmentAttachment att) async {
    return resolveIn(await appRoot(), att);
  }

  static Future<AssessmentAttachment> saveUpload({
    required String uid,
    required String assessmentId,
    required String filename,
    String? sourcePath,
    List<int>? bytes,
  }) async {
    final id = AssessmentAttachment.newId();
    final relative = relativePathFor(
      uid: uid,
      assessmentId: assessmentId,
      attachmentId: id,
      filename: filename,
    );
    final root = await appRoot();
    final dest = File(
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    await dest.parent.create(recursive: true);
    if (bytes != null && bytes.isNotEmpty) {
      await dest.writeAsBytes(bytes, flush: true);
    } else if (sourcePath != null && sourcePath.trim().isNotEmpty) {
      await File(sourcePath).copy(dest.path);
    } else {
      throw StateError('No file data to store.');
    }
    return AssessmentAttachment(
      id: id,
      kind: AssessmentAttachmentKind.file,
      name: AssessmentAttachment.basename(filename),
      relativePath: relative,
      absolutePath: dest.path,
      sourceAssessmentId: assessmentId,
    );
  }

  static Future<void> deleteOwnedFile({
    required String assessmentId,
    required AssessmentAttachment att,
  }) async {
    if (!att.isFile) return;
    final rel = (att.relativePath ?? '').trim();
    final owns = rel.contains('/$assessmentId/') ||
        (att.sourceAssessmentId != null &&
            att.sourceAssessmentId == assessmentId);
    if (!owns) return;
    try {
      final file = await resolve(att);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  static Future<void> deleteAssessmentFolder({
    required String uid,
    required String assessmentId,
  }) async {
    try {
      final root = await appRoot();
      final dir = Directory(
        '${root.path}${Platform.pathSeparator}$folderName'
        '${Platform.pathSeparator}$uid'
        '${Platform.pathSeparator}$assessmentId',
      );
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
