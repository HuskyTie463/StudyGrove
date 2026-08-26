import 'package:flutter/material.dart';
import '../utils/datetime_utils.dart';

class TaskItem {
  TaskItem({required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;
}

class Subject {
  Subject({
    required this.id,
    required this.name,
    required this.colorValue,
    this.code,
  });

  final String id;
  final String name;
  final String? code;
  final int colorValue;

  Color get color => Color(colorValue);

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
    this.isRecurring = false,
  }) : endMinutes = resolveEndMinutes(startMinutes, endMinutes);

  final String id;
  final String title;
  final String dayKey;
  final int startMinutes;
  final int endMinutes;
  final String? location;
  final String? subjectId;
  final bool isRecurring;

  TimeOfDay get start =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get end =>
      TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 24 * 60);
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
  }) : endMinutes = resolveEndMinutes(startMinutes, endMinutes);

  final String id;
  final String title;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String? location;
  final String? subjectId;

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
    this.completed = false,
    this.archived = false,
    this.resultReflection,
    this.timeZoneId,
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
  final bool completed;
  final bool archived;
  final String? resultReflection;
  final String? timeZoneId;

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
    bool? completed,
    bool? archived,
    String? resultReflection,
    String? timeZoneId,
  }) {
    return Assessment(
      id: id,
      title: title ?? this.title,
      course: course ?? this.course,
      dueDate: dueDate ?? this.dueDate,
      subtasks: subtasks ?? this.subtasks,
      subjectId: subjectId ?? this.subjectId,
      type: type ?? this.type,
      weightPercent: clearWeight ? null : (weightPercent ?? this.weightPercent),
      estimatedPrepMinutes:
          clearPrep ? null : (estimatedPrepMinutes ?? this.estimatedPrepMinutes),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      linkedTopicIds: linkedTopicIds ?? this.linkedTopicIds,
      notes: notes ?? this.notes,
      fileLinks: fileLinks ?? this.fileLinks,
      completed: completed ?? this.completed,
      archived: archived ?? this.archived,
      resultReflection: resultReflection ?? this.resultReflection,
      timeZoneId: timeZoneId ?? this.timeZoneId,
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
