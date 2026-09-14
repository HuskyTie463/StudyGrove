import 'dart:io';

import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/services/assessment_attachment_store.dart';
import 'package:flutter_organiser/ui/assessment_materials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attachment toMap/fromMap round trip', () {
    const att = AssessmentAttachment(
      id: 'att_1',
      kind: AssessmentAttachmentKind.lecture,
      name: 'Week 3 lecture',
      lectureId: 'lec_9',
    );
    final parsed = AssessmentAttachment.fromMap(att.toMap());
    expect(parsed, isNotNull);
    expect(parsed!.id, 'att_1');
    expect(parsed.kind, AssessmentAttachmentKind.lecture);
    expect(parsed.name, 'Week 3 lecture');
    expect(parsed.lectureId, 'lec_9');
    expect(parsed.linkKey, 'lecture:lec_9');
    expect(parsed.isLecture, isTrue);
  });

  test('listFromAssessmentData prefers attachments over fileLinks', () {
    final list = AssessmentAttachment.listFromAssessmentData({
      'attachments': [
        {
          'id': 'a1',
          'kind': 'file',
          'name': 'brief.pdf',
          'relativePath': 'assessment_files/u/a/a1_brief.pdf',
        },
        {
          'id': 'a2',
          'kind': 'lecture',
          'name': 'Intro',
          'lectureId': 'L1',
        },
      ],
      'fileLinks': ['ignored.pdf'],
    });
    expect(list, hasLength(2));
    expect(list.first.name, 'brief.pdf');
    expect(list.last.kind, AssessmentAttachmentKind.lecture);
  });

  test('legacy fileLinks become file attachments', () {
    final list = AssessmentAttachment.listFromAssessmentData({
      'fileLinks': [
        r'C:\notes\rubric.pdf',
        'https://example.com/spec.docx',
      ],
    });
    expect(list, hasLength(2));
    expect(list.first.name, 'rubric.pdf');
    expect(list.first.kind, AssessmentAttachmentKind.file);
    expect(list.last.name, 'spec.docx');
  });

  test('copyWith replaces attachments', () {
    final a = Assessment(
      id: '1',
      title: 'Essay',
      course: 'HIST',
      dueDate: DateTime(2026, 9, 20),
      subtasks: const [],
    );
    expect(a.attachments, isEmpty);
    final next = a.copyWith(
      attachments: const [
        AssessmentAttachment(
          id: 'n1',
          kind: AssessmentAttachmentKind.note,
          name: 'Plan',
          noteId: 'note_1',
        ),
      ],
    );
    expect(next.attachments, hasLength(1));
    expect(next.attachments.single.linkKey, 'note:note_1');
    expect(a.attachments, isEmpty);
  });

  test('sanitize and relative paths stay inside assessment folder', () {
    expect(AssessmentAttachmentStore.sanitizeFilename('a/b:c*.pdf'), 'a_b_c_.pdf');
    expect(AssessmentAttachment.basename(r'C:\tmp\week 2.pdf'), 'week 2.pdf');
    final rel = AssessmentAttachmentStore.relativePathFor(
      uid: 'u1',
      assessmentId: 'ass1',
      attachmentId: 'att9',
      filename: 'Week 2.pdf',
    );
    expect(rel, 'assessment_files/u1/ass1/att9_Week 2.pdf');
    const att = AssessmentAttachment(
      id: 'att9',
      kind: AssessmentAttachmentKind.file,
      name: 'Week 2.pdf',
      relativePath: 'assessment_files/u1/ass1/att9_Week 2.pdf',
    );
    final file = AssessmentAttachmentStore.resolveIn(Directory('/root'), att);
    expect(file.path.contains('assessment_files'), isTrue);
    expect(file.path.contains('ass1'), isTrue);
  });

  test('libraryFilesFrom dedupes shared files', () {
    const shared = AssessmentAttachment(
      id: 'f1',
      kind: AssessmentAttachmentKind.file,
      name: 'slides.pdf',
      relativePath: 'assessment_files/u/a/f1_slides.pdf',
    );
    final assessments = [
      Assessment(
        id: 'a',
        title: 'One',
        course: 'A',
        dueDate: DateTime(2026, 1, 1),
        subtasks: const [],
        attachments: const [shared],
      ),
      Assessment(
        id: 'b',
        title: 'Two',
        course: 'B',
        dueDate: DateTime(2026, 1, 2),
        subtasks: const [],
        attachments: const [shared],
      ),
    ];
    expect(libraryFilesFrom(assessments), hasLength(1));
  });

  test('image detection and labels', () {
    const img = AssessmentAttachment(
      id: 'i',
      kind: AssessmentAttachmentKind.file,
      name: 'scan.PNG',
    );
    expect(img.isImage, isTrue);
    expect(AssessmentAttachmentKind.lecture.label, 'Lecture');
  });
}
