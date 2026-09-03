import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'lecture_file_import.dart';
import 'study_ai_client.dart';
import 'study_ai_settings.dart';

/// Lecture Lab. Uses the Study AI proxy when available.
class LectureLabService {
  LectureLabService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  bool get supportsAi => studyAiSettings.hasKey;

  CollectionReference<Map<String, dynamic>> get _lectures =>
      _db.collection('users').doc(uid).collection('lectures');

  CollectionReference<Map<String, dynamic>> get _topics =>
      _db.collection('users').doc(uid).collection('review_topics');

  Stream<List<LectureNote>> streamLectures() {
    return _lectures.orderBy('createdAt', descending: true).snapshots().map((s) {
      return s.docs.map((d) {
        final data = d.data();
        return LectureNote(
          id: d.id,
          title: (data['title'] as String?) ?? 'Lecture',
          body: (data['body'] as String?) ?? '',
          course: data['course'] as String?,
          subjectId: data['subjectId'] as String?,
          lectureDate: (data['lectureDate'] as Timestamp?)?.toDate(),
          topicIds: ((data['topicIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          assessmentIds: ((data['assessmentIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          learningObjectives:
              ((data['learningObjectives'] as List?) ?? const [])
                  .map((e) => e.toString())
                  .where((e) => e.trim().isNotEmpty)
                  .toList(),
        );
      }).toList();
    });
  }

  Stream<List<ReviewTopic>> streamTopics() {
    return _topics.snapshots().map((s) {
      return s.docs.map((d) {
        final data = d.data();
        final rawQs = (data['questions'] as List?) ?? const [];
        final qs = rawQs.map((x) {
          final m = Map<String, dynamic>.from(x as Map);
          return RecallQuestion(
            id: (m['id'] as String?) ?? '',
            prompt: (m['prompt'] as String?) ?? '',
            answer: m['answer'] as String?,
            sourceExcerpt: m['sourceExcerpt'] as String?,
            unsupported: (m['unsupported'] as bool?) ?? false,
          );
        }).toList();
        return ReviewTopic(
          id: d.id,
          title: (data['title'] as String?) ?? '',
          course: data['course'] as String?,
          subjectId: data['subjectId'] as String?,
          assessmentIds: ((data['assessmentIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          confidence: (data['confidence'] as num?)?.toDouble(),
          lastReviewedAt: (data['lastReviewedAt'] as Timestamp?)?.toDate(),
          nextReviewAt: (data['nextReviewAt'] as Timestamp?)?.toDate(),
          stabilityDays: (data['stabilityDays'] as num?)?.toDouble(),
          sourceLectureId: data['sourceLectureId'] as String?,
          questions: qs,
          learningObjective: data['learningObjective'] as String?,
        );
      }).toList();
    });
  }

  /// Manual fallback: split body into topic candidates by headings / bullets.
  List<String> extractTopicsManual(String body) {
    final lines = body
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final topics = <String>[];
    for (final line in lines) {
      final cleaned = line
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceFirst(RegExp(r'^[-*•]\s*'), '')
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
          .trim();
      if (cleaned.length < 4 || cleaned.length > 80) continue;
      if (cleaned.split(' ').length > 12) continue;
      if (!topics.contains(cleaned)) topics.add(cleaned);
      if (topics.length >= 12) break;
    }
    return topics;
  }

  /// When objectives exist, keep only concepts that overlap an objective.
  List<({String title, String? objective})> extractAlignedTopics({
    required String body,
    required List<String> objectives,
  }) {
    final raw = extractTopicsManual(body);
    if (objectives.isEmpty) {
      return raw.map((t) => (title: t, objective: null)).toList();
    }
    final out = <({String title, String? objective})>[];
    for (final obj in objectives) {
      final trimmed = obj.trim();
      if (trimmed.isEmpty) continue;
      out.add((title: trimmed, objective: trimmed));
      for (final t in raw) {
        if (_overlaps(t, trimmed) &&
            !out.any((e) => e.title.toLowerCase() == t.toLowerCase())) {
          out.add((title: t, objective: trimmed));
        }
      }
    }
    return out.take(16).toList();
  }

  bool _overlaps(String a, String b) {
    final aw = a
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length >= 4)
        .toSet();
    final bw = b
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length >= 4)
        .toSet();
    if (aw.isEmpty || bw.isEmpty) {
      return a.toLowerCase().contains(b.toLowerCase()) ||
          b.toLowerCase().contains(a.toLowerCase());
    }
    return aw.intersection(bw).isNotEmpty;
  }

  /// Generates simple cloze-style questions from a topic + source excerpt.
  /// Marks unsupported when no source excerpt can back the answer.
  List<RecallQuestion> generateQuestionsManual({
    required String topic,
    required String sourceBody,
  }) {
    final excerpt = _findExcerpt(sourceBody, topic);
    final unsupported = excerpt == null;
    final base = topic.length > 40 ? '${topic.substring(0, 40)}…' : topic;
    return [
      RecallQuestion(
        id: 'q1',
        prompt: 'In your own words: what idea is "$base" capturing, and when would you use it?',
        answer: unsupported
            ? null
            : 'See source: “${excerpt.length > 120 ? '${excerpt.substring(0, 120)}…' : excerpt}”',
        sourceExcerpt: excerpt,
        unsupported: unsupported,
      ),
      RecallQuestion(
        id: 'q2',
        prompt: 'Give a situation where "$base" applies. What would change if one part of it changed?',
        answer: null,
        sourceExcerpt: excerpt,
        unsupported: unsupported,
      ),
      RecallQuestion(
        id: 'q3',
        prompt: 'Which nearby idea is easy to mix up with "$base", and how do you tell them apart in meaning?',
        answer: null,
        sourceExcerpt: excerpt,
        unsupported: true,
      ),
    ];
  }

  String? _findExcerpt(String body, String topic) {
    final lower = body.toLowerCase();
    final key = topic.toLowerCase().split(' ').first;
    final idx = lower.indexOf(key);
    if (idx < 0) return null;
    final start = (idx - 40).clamp(0, body.length);
    final end = (idx + topic.length + 80).clamp(0, body.length);
    return body.substring(start, end).trim();
  }

  Future<String> saveLecture({
    required String title,
    required String body,
    String? course,
    String? subjectId,
    DateTime? lectureDate,
    List<String> assessmentIds = const [],
    List<String> learningObjectives = const [],
    List<int>? pdfBytes,
    String? pdfFilename,
  }) async {
    final pasted = body.trim();
    final localPdf = (pdfBytes != null && pdfBytes.isNotEmpty)
        ? LectureFileImport.extractPdfText(pdfBytes)
        : '';
    final storedBody = pasted.isNotEmpty ? pasted : localPdf;
    final sendPdfToModel = studyAiSettings.provider == StudyAiProvider.anthropic &&
        pdfBytes != null &&
        pdfBytes.isNotEmpty;

    List<({String title, String? objective, List<RecallQuestion> questions})>
        aligned;
    var usedAi = false;
    if (studyAiSettings.hasKey) {
      try {
        final extracted = await StudyAiClient.instance.extractLecture(
          title: title,
          body: sendPdfToModel ? pasted : storedBody,
          objectives: learningObjectives,
          pdfBytes: pdfBytes,
          pdfFilename: pdfFilename,
        );
        aligned = extracted
            .map(
              (e) => (
                title: e.title,
                objective: e.objective,
                questions: e.questions,
              ),
            )
            .toList();
        usedAi = true;
      } catch (_) {
        if (storedBody.isEmpty) rethrow;
        aligned = extractAlignedTopics(
          body: storedBody,
          objectives: learningObjectives,
        ).map((e) => (title: e.title, objective: e.objective, questions: <RecallQuestion>[])).toList();
      }
    } else {
      if (storedBody.isEmpty) {
        throw StudyAiException(
          'Could not read text from ${pdfFilename ?? 'the PDF'}. Add an API key in Settings to extract with AI, or paste notes.',
        );
      }
      aligned = extractAlignedTopics(
        body: storedBody,
        objectives: learningObjectives,
      ).map((e) => (title: e.title, objective: e.objective, questions: <RecallQuestion>[])).toList();
    }
    final topicIds = <String>[];

    for (final item in aligned) {
      final qs = item.questions.isNotEmpty
          ? item.questions
          : generateQuestionsManual(topic: item.title, sourceBody: storedBody);
      final ref = await _topics.add({
        'title': item.title,
        'course': course,
        'subjectId': subjectId,
        'assessmentIds': assessmentIds,
        'confidence': null,
        'lastReviewedAt': null,
        'nextReviewAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
        'stabilityDays': null,
        'learningObjective': item.objective,
        'questions': qs
            .map((q) => {
                  'id': q.id,
                  'prompt': q.prompt,
                  'answer': q.answer,
                  'sourceExcerpt': q.sourceExcerpt,
                  'unsupported': q.unsupported,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      topicIds.add(ref.id);
    }

    final doc = await _lectures.add({
      'title': title,
      'body': storedBody,
      'course': course,
      'subjectId': subjectId,
      'lectureDate':
          lectureDate == null ? null : Timestamp.fromDate(lectureDate),
      'topicIds': topicIds,
      'assessmentIds': assessmentIds,
      'learningObjectives': learningObjectives,
      'extractedWithAi': usedAi,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final id in topicIds) {
      await _topics.doc(id).update({'sourceLectureId': doc.id});
    }

    return doc.id;
  }

  Future<void> scheduleReview(String topicId, DateTime when) async {
    await _topics.doc(topicId).set({
      'nextReviewAt': Timestamp.fromDate(when),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> recordReview(String topicId, double confidence) async {
    final v = confidence.clamp(0.0, 1.0);
    final intervalDays = v < 0.4 ? 1 : (v < 0.7 ? 3 : 7);
    await _topics.doc(topicId).set({
      'confidence': v,
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'nextReviewAt': Timestamp.fromDate(
        DateTime.now().add(Duration(days: intervalDays)),
      ),
      'stabilityDays': intervalDays.toDouble(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
