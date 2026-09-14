import 'package:flutter/material.dart';
import '../utils/datetime_utils.dart';

enum TaskUrgency { normal, urgent }

extension TaskUrgencyX on TaskUrgency {
  String get label => switch (this) {
        TaskUrgency.normal => 'Normal',
        TaskUrgency.urgent => 'Urgent',
      };

  String get storage => name;

  static TaskUrgency fromStorage(String? value) {
    return TaskUrgency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskUrgency.normal,
    );
  }
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.done = false,
    this.urgency = TaskUrgency.normal,
    this.subjectId,
  });
  final String id;
  final String title;
  final bool done;
  final TaskUrgency urgency;
  final String? subjectId;

  bool get isUrgent => urgency == TaskUrgency.urgent;
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    this.updatedAt,
    this.subjectId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? updatedAt;
  final String? subjectId;
}

class StudyDayTotal {
  StudyDayTotal({
    required this.subjectId,
    required this.dayKey,
    required this.minutes,
  });

  final String subjectId;
  final String dayKey;
  final int minutes;
}

enum SubjectKind {
  study,
  hobby;

  static SubjectKind fromStorage(String? value) {
    return value == hobby.name ? hobby : study;
  }

  bool get isHobby => this == hobby;
}

class Subject {
  Subject({
    required this.id,
    required this.name,
    required this.colorValue,
    this.code,
    this.kind = SubjectKind.study,
    this.weekGoalHours,
  });

  final String id;
  final String name;
  final String? code;
  final int colorValue;
  final SubjectKind kind;
  final int? weekGoalHours;

  Color get color => Color(colorValue);

  bool get isHobby => kind.isHobby;

  String get label {
    final c = code?.trim();
    if (c == null || c.isEmpty) return name;
    return '$c · $name';
  }
}

class AppEvent {
  AppEvent({
    required this.id,
    required this.title,
    required this.dayKey,
    required this.startMinutes,
    int? endMinutes,
    this.location,
    this.subjectId,
    this.colorValue,
    this.isRecurring = false,
  }) : endMinutes = resolveEndMinutes(startMinutes, endMinutes);

  final String id;
  final String title;
  final String dayKey;
  final int startMinutes;
  final int endMinutes;
  final String? location;
  final String? subjectId;
  final int? colorValue;
  final bool isRecurring;

  TimeOfDay get start =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get end =>
      TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60);

  Color? get color => colorValue == null ? null : Color(colorValue!);

  /// Chosen event colour, then subject colour, then theme fallback.
  Color resolvedColor({Color? subjectColor, required Color fallback}) {
    return color ?? subjectColor ?? fallback;
  }
}

class RecurringEvent {
  RecurringEvent({
    required this.id,
    required this.title,
    required this.weekday,
    required this.startMinutes,
    int? endMinutes,
    this.location,
    this.subjectId,
    this.colorValue,
  }) : endMinutes = resolveEndMinutes(startMinutes, endMinutes);

  final String id;
  final String title;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String? location;
  final String? subjectId;
  final int? colorValue;

  TimeOfDay get start =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get end =>
      TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60);
}

class AssessmentSubtask {
  AssessmentSubtask({required this.title, this.done = false});
  final String title;
  bool done;

  Map<String, dynamic> toMap() => {'title': title, 'done': done};

  static AssessmentSubtask fromMap(Map<String, dynamic> m) {
    return AssessmentSubtask(
      title: (m['title'] as String?) ?? '',
      done: (m['done'] as bool?) ?? false,
    );
  }
}

enum AssessmentType {
  exam,
  assignment,
  reportLab,
  other,
}

extension AssessmentTypeX on AssessmentType {
  String get label => switch (this) {
        AssessmentType.exam => 'Exam',
        AssessmentType.assignment => 'Assignment',
        AssessmentType.reportLab => 'Report / Lab',
        AssessmentType.other => 'Other',
      };

  String get storage => name;

  static AssessmentType fromStorage(String? value) {
    return AssessmentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AssessmentType.other,
    );
  }
}

enum AssessmentAttachmentKind { file, lecture, note }

extension AssessmentAttachmentKindX on AssessmentAttachmentKind {
  String get storage => name;

  String get label => switch (this) {
        AssessmentAttachmentKind.file => 'File',
        AssessmentAttachmentKind.lecture => 'Lecture',
        AssessmentAttachmentKind.note => 'Note',
      };

  static AssessmentAttachmentKind fromStorage(String? value) {
    return AssessmentAttachmentKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AssessmentAttachmentKind.file,
    );
  }
}

class AssessmentAttachment {
  const AssessmentAttachment({
    required this.id,
    required this.kind,
    required this.name,
    this.relativePath,
    this.absolutePath,
    this.lectureId,
    this.noteId,
    this.sourceAssessmentId,
  });

  final String id;
  final AssessmentAttachmentKind kind;
  final String name;
  final String? relativePath;
  final String? absolutePath;
  final String? lectureId;
  final String? noteId;
  final String? sourceAssessmentId;

  bool get isFile => kind == AssessmentAttachmentKind.file;
  bool get isLecture => kind == AssessmentAttachmentKind.lecture;
  bool get isNote => kind == AssessmentAttachmentKind.note;

  bool get isImage {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp') ||
        n.endsWith('.heic');
  }

  /// Dedupes picks so the same lecture/file is not attached twice.
  String get linkKey => switch (kind) {
        AssessmentAttachmentKind.file =>
          'file:${relativePath ?? absolutePath ?? name}',
        AssessmentAttachmentKind.lecture => 'lecture:${lectureId ?? id}',
        AssessmentAttachmentKind.note => 'note:${noteId ?? id}',
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.storage,
        'name': name,
        if (relativePath != null) 'relativePath': relativePath,
        if (absolutePath != null) 'absolutePath': absolutePath,
        if (lectureId != null) 'lectureId': lectureId,
        if (noteId != null) 'noteId': noteId,
        if (sourceAssessmentId != null) 'sourceAssessmentId': sourceAssessmentId,
      };

  static AssessmentAttachment? fromMap(Map<String, dynamic> m) {
    final id = (m['id'] as String?)?.trim() ?? '';
    final name = (m['name'] as String?)?.trim() ?? '';
    if (id.isEmpty && name.isEmpty) return null;
    return AssessmentAttachment(
      id: id.isEmpty ? 'att_${name.hashCode}' : id,
      kind: AssessmentAttachmentKindX.fromStorage(m['kind'] as String?),
      name: name.isEmpty ? 'File' : name,
      relativePath: m['relativePath'] as String?,
      absolutePath: m['absolutePath'] as String?,
      lectureId: m['lectureId'] as String?,
      noteId: m['noteId'] as String?,
      sourceAssessmentId: m['sourceAssessmentId'] as String?,
    );
  }

  static String basename(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return 'File';
    final parts = trimmed.split(RegExp(r'[\\/]'));
    final last = parts.isEmpty ? trimmed : parts.last;
    return last.isEmpty ? 'File' : last;
  }

  static List<AssessmentAttachment> listFromAssessmentData(
    Map<String, dynamic> data,
  ) {
    final raw = data['attachments'];
    final out = <AssessmentAttachment>[];
    if (raw is List) {
      for (final x in raw) {
        if (x is! Map) continue;
        final parsed = fromMap(Map<String, dynamic>.from(x));
        if (parsed != null) out.add(parsed);
      }
    }
    if (out.isNotEmpty) return out;

    final links = (data['fileLinks'] as List?) ?? const [];
    var i = 0;
    for (final e in links) {
      final s = e.toString().trim();
      if (s.isEmpty) continue;
      out.add(
        AssessmentAttachment(
          id: 'legacy_${s.hashCode}_$i',
          kind: AssessmentAttachmentKind.file,
          name: basename(s),
          absolutePath: s,
        ),
      );
      i++;
    }
    return out;
  }

  static String newId() {
    final now = DateTime.now();
    return 'att_${now.microsecondsSinceEpoch.toRadixString(16)}'
        '_${now.millisecond}';
  }
}

class Assessment {
  Assessment({
    required this.id,
    required this.title,
    required this.course,
    required this.dueDate,
    required this.subtasks,
    this.subjectId,
    this.type = AssessmentType.other,
    this.weightPercent,
    this.estimatedPrepMinutes,
    this.confidence,
    this.linkedTopicIds = const [],
    this.notes,
    this.fileLinks = const [],
    this.attachments = const [],
    this.completed = false,
    this.archived = false,
    this.resultReflection,
    this.timeZoneId,
    this.spentSeconds = 0,
  });

  final String id;
  final String title;
  final String course;
  final DateTime dueDate;
  final List<AssessmentSubtask> subtasks;
  final String? subjectId;
  final AssessmentType type;
  /// Course weight 0–100; null means unset (ask user, do not invent).
  final double? weightPercent;
  /// Estimated remaining prep minutes; null means unset.
  final int? estimatedPrepMinutes;
  /// Self-reported confidence 0–1; null means unset.
  final double? confidence;
  final List<String> linkedTopicIds;
  final String? notes;
  final List<String> fileLinks;
  final List<AssessmentAttachment> attachments;
  final bool completed;
  final bool archived;
  final String? resultReflection;
  final String? timeZoneId;
  /// Cumulative study seconds logged on this assessment (timer + saved sessions).
  final int spentSeconds;

  double get progress => subtasks.isEmpty
      ? 0
      : subtasks.where((s) => s.done).length / subtasks.length;

  int get openSubtaskCount => subtasks.where((s) => !s.done).length;

  int get daysUntilDue {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return b.difference(a).inDays;
  }

  String get dueLabel {
    final diff = daysUntilDue;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff > 1) return 'Due in $diff days';
    return 'Overdue (${diff.abs()}d)';
  }

  bool get isActive => !completed && !archived;

  Assessment copyWith({
    String? title,
    String? course,
    DateTime? dueDate,
    List<AssessmentSubtask>? subtasks,
    String? subjectId,
    bool clearSubject = false,
    AssessmentType? type,
    double? weightPercent,
    bool clearWeight = false,
    int? estimatedPrepMinutes,
    bool clearPrep = false,
    double? confidence,
    bool clearConfidence = false,
    List<String>? linkedTopicIds,
    String? notes,
    List<String>? fileLinks,
    List<AssessmentAttachment>? attachments,
    bool? completed,
    bool? archived,
    String? resultReflection,
    String? timeZoneId,
    int? spentSeconds,
  }) {
    return Assessment(
      id: id,
      title: title ?? this.title,
      course: course ?? this.course,
      dueDate: dueDate ?? this.dueDate,
      subtasks: subtasks ?? this.subtasks,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      type: type ?? this.type,
      weightPercent: clearWeight ? null : (weightPercent ?? this.weightPercent),
      estimatedPrepMinutes:
          clearPrep ? null : (estimatedPrepMinutes ?? this.estimatedPrepMinutes),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      linkedTopicIds: linkedTopicIds ?? this.linkedTopicIds,
      notes: notes ?? this.notes,
      fileLinks: fileLinks ?? this.fileLinks,
      attachments: attachments ?? this.attachments,
      completed: completed ?? this.completed,
      archived: archived ?? this.archived,
      resultReflection: resultReflection ?? this.resultReflection,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      spentSeconds: spentSeconds ?? this.spentSeconds,
    );
  }
}

/// Review / recall topic for Memory Weather and Lecture Lab.
class ReviewTopic {
  ReviewTopic({
    required this.id,
    required this.title,
    this.course,
    this.subjectId,
    this.assessmentIds = const [],
    this.confidence,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.stabilityDays,
    this.sourceLectureId,
    this.questions = const [],
    this.learningObjective,
  });

  final String id;
  final String title;
  final String? course;
  final String? subjectId;
  final List<String> assessmentIds;
  final double? confidence;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final double? stabilityDays;
  final String? sourceLectureId;
  final List<RecallQuestion> questions;
  final String? learningObjective;
}

class RecallQuestion {
  RecallQuestion({
    required this.id,
    required this.prompt,
    this.answer,
    this.sourceExcerpt,
    this.unsupported = false,
  });

  final String id;
  final String prompt;
  final String? answer;
  final String? sourceExcerpt;
  final bool unsupported;
}

class LectureKeyIdea {
  const LectureKeyIdea({required this.title, this.detail = ''});

  final String title;
  final String detail;

  Map<String, dynamic> toMap() => {
        'title': title,
        'detail': detail,
      };

  static LectureKeyIdea? tryParse(dynamic raw) {
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      return LectureKeyIdea(title: t);
    }
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final title = (m['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;
    return LectureKeyIdea(
      title: title,
      detail: (m['detail'] as String?)?.trim() ??
          (m['body'] as String?)?.trim() ??
          '',
    );
  }
}

class LectureTable {
  const LectureTable({
    this.caption,
    this.headers = const [],
    this.rows = const [],
  });

  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;

  Map<String, dynamic> toMap() => {
        'caption': caption,
        'headers': headers,
        'rows': rows.map((r) => {'cells': r}).toList(),
      };

  static LectureTable? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final headers = ((m['headers'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final rows = <List<String>>[];
    for (final row in (m['rows'] as List?) ?? const []) {
      if (row is List) {
        rows.add(row.map((e) => e.toString()).toList());
      } else if (row is Map) {
        final cells = (row['cells'] as List?) ?? const [];
        rows.add(cells.map((e) => e.toString()).toList());
      }
    }
    if (headers.isEmpty && rows.isEmpty) return null;
    final caption = (m['caption'] as String?)?.trim();
    return LectureTable(
      caption: caption == null || caption.isEmpty ? null : caption,
      headers: headers,
      rows: rows,
    );
  }
}

class LectureNote {
  LectureNote({
    required this.id,
    required this.title,
    required this.body,
    this.course,
    this.subjectId,
    this.lectureDate,
    this.topicIds = const [],
    this.assessmentIds = const [],
    this.learningObjectives = const [],
    this.summary,
    this.keyIdeas = const [],
    this.tables = const [],
  });

  final String id;
  final String title;
  final String body;
  final String? course;
  final String? subjectId;
  final DateTime? lectureDate;
  final List<String> topicIds;
  final List<String> assessmentIds;
  final List<String> learningObjectives;
  final String? summary;
  final List<LectureKeyIdea> keyIdeas;
  final List<LectureTable> tables;
}

enum FrictionReason {
  tooTired,
  travel,
  wrongTask,
  tooDifficult,
  tooLong,
  wrongEnvironment,
  somethingChanged,
}

extension FrictionReasonX on FrictionReason {
  String get label => switch (this) {
        FrictionReason.tooTired => 'Too tired',
        FrictionReason.travel => 'Travel',
        FrictionReason.wrongTask => 'Wrong task',
        FrictionReason.tooDifficult => 'Too difficult',
        FrictionReason.tooLong => 'Too long',
        FrictionReason.wrongEnvironment => 'Wrong environment',
        FrictionReason.somethingChanged => 'Something changed',
      };

  String get storage => name;

  static FrictionReason fromStorage(String? value) {
    return FrictionReason.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FrictionReason.somethingChanged,
    );
  }
}

enum StudyContextMode {
  desk,
  walking,
  lowEnergy,
  balanced,
}

extension StudyContextModeX on StudyContextMode {
  String get label => switch (this) {
        StudyContextMode.desk => 'Desk',
        StudyContextMode.walking => 'Walking',
        StudyContextMode.lowEnergy => 'Low energy',
        StudyContextMode.balanced => 'Balanced',
      };
}

enum MemoryWeatherState {
  clear,
  clouding,
  fog,
  recoveryUnderway,
}

extension MemoryWeatherStateX on MemoryWeatherState {
  String get label => switch (this) {
        MemoryWeatherState.clear => 'Clear',
        MemoryWeatherState.clouding => 'Clouding',
        MemoryWeatherState.fog => 'Fog',
        MemoryWeatherState.recoveryUnderway => 'Recovery underway',
      };
}

class AgendaSlotItem {
  AgendaSlotItem({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};

  static AgendaSlotItem fromMap(Map<String, dynamic> m) {
    return AgendaSlotItem(
      id: (m['id'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      done: (m['done'] as bool?) ?? false,
    );
  }
}

/// Soft palette for new subjects.
const List<int> kSubjectColorPalette = [
  0xFF6FA98A,
  0xFFE8B4A0,
  0xFF7BA3C9,
  0xFFC9A0DC,
  0xFFE8C47C,
  0xFF8FB8A8,
  0xFFD4A5A5,
  0xFF9BB0C1,
  0xFFB8A9C9,
  0xFFA3C9A8,
];
