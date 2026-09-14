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
    return _lectures.snapshots().map((s) {
      final rows = <({DateTime created, LectureNote note})>[];
      for (final d in s.docs) {
        final data = d.data();
        rows.add((
          created: _asDate(data['createdAt']) ??
              _asDate(data['lectureDate']) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          note: lectureFromDoc(d.id, data),
        ));
      }
      rows.sort((a, b) => b.created.compareTo(a.created));
      return rows.map((e) => e.note).toList();
    });
  }

  Future<LectureNote?> getLecture(String id) async {
    final snap = await _lectures.doc(id).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return lectureFromDoc(id, data);
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  static List<String> _asStringList(dynamic value) {
    return _asList(value)
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  static LectureNote lectureFromDoc(String id, Map<String, dynamic> data) {
    final keyIdeas = <LectureKeyIdea>[];
    for (final item in _asList(data['keyIdeas'])) {
      final idea = LectureKeyIdea.tryParse(item);
      if (idea != null) keyIdeas.add(idea);
    }
    final tables = <LectureTable>[];
    for (final item in _asList(data['tables'])) {
      final table = LectureTable.tryParse(item);
      if (table != null) tables.add(table);
    }
    final body = _asString(data['body']) ?? '';
    if (tables.isEmpty) {
      tables.addAll(parseMarkdownTables(body));
    }
    final summary = _asString(data['summary'])?.trim();
    return LectureNote(
      id: id,
      title: (_asString(data['title']) ?? '').trim().isEmpty
          ? 'Lecture'
          : _asString(data['title'])!.trim(),
      body: body,
      course: _asString(data['course']),
      subjectId: _asString(data['subjectId']),
      lectureDate: _asDate(data['lectureDate']),
      topicIds: _asStringList(data['topicIds']),
      assessmentIds: _asStringList(data['assessmentIds']),
      learningObjectives: _asStringList(data['learningObjectives']),
      summary: (summary == null || summary.isEmpty) ? null : summary,
      keyIdeas: keyIdeas,
      tables: tables,
    );
  }

  static List<LectureTable> parseMarkdownTables(String body) {
    List<String> splitRow(String line) {
      var s = line.trim();
      if (s.startsWith('|')) s = s.substring(1);
      if (s.endsWith('|')) s = s.substring(0, s.length - 1);
      return s.split('|').map((c) => c.trim()).toList();
    }

    bool isSeparator(String line) {
      if (!line.contains('|') && !line.contains('-')) return false;
      final cells = splitRow(line);
      if (cells.isEmpty) return false;
      return cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
    }

    final lines = body.split(RegExp(r'\r?\n'));
    final out = <LectureTable>[];
    for (var i = 0; i < lines.length - 1; i++) {
      if (!lines[i].contains('|') || !isSeparator(lines[i + 1])) continue;
      final headers = splitRow(lines[i]);
      if (headers.where((h) => h.isNotEmpty).isEmpty) continue;
      final rows = <List<String>>[];
      var j = i + 2;
      while (j < lines.length && lines[j].contains('|')) {
        if (isSeparator(lines[j])) {
          j++;
          continue;
        }
        final row = splitRow(lines[j]);
        if (row.any((c) => c.isNotEmpty)) rows.add(row);
        j++;
      }
      if (rows.isEmpty) continue;
      out.add(LectureTable(headers: headers, rows: rows));
      i = j - 1;
    }
    return out;
  }

  Stream<List<ReviewTopic>> streamTopics() {
    return _topics.snapshots().map((s) {
      return s.docs.map((d) {
        final data = d.data();
        final qs = <RecallQuestion>[];
        for (final x in _asList(data['questions'])) {
          if (x is! Map) continue;
          final m = Map<String, dynamic>.from(x);
          qs.add(
            RecallQuestion(
              id: _asString(m['id']) ?? '',
              prompt: _asString(m['prompt']) ?? '',
              answer: _asString(m['answer']),
              sourceExcerpt: _asString(m['sourceExcerpt']),
              unsupported: m['unsupported'] == true,
            ),
          );
        }
        return ReviewTopic(
          id: d.id,
          title: _asString(data['title']) ?? '',
          course: _asString(data['course']),
          subjectId: _asString(data['subjectId']),
          assessmentIds: _asStringList(data['assessmentIds']),
          confidence: (data['confidence'] as num?)?.toDouble(),
          lastReviewedAt: _asDate(data['lastReviewedAt']),
          nextReviewAt: _asDate(data['nextReviewAt']),
          stabilityDays: (data['stabilityDays'] as num?)?.toDouble(),
          sourceLectureId: _asString(data['sourceLectureId']),
          questions: qs,
          learningObjective: _asString(data['learningObjective']),
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
        prompt: 'What is $base?',
        answer: unsupported
            ? null
            : (excerpt.length > 140 ? '${excerpt.substring(0, 140).trim()}…' : excerpt),
        sourceExcerpt: excerpt,
        unsupported: unsupported,
      ),
      RecallQuestion(
        id: 'q2',
        prompt: 'Define: $base',
        answer: unsupported ? null : 'The notes define $base in that lecture passage.',
        sourceExcerpt: excerpt,
        unsupported: unsupported,
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
    String? summary;
    var keyIdeas = <LectureKeyIdea>[];
    var tables = <LectureTable>[];
    if (studyAiSettings.hasKey) {
      try {
        final extracted = await StudyAiClient.instance.extractLecture(
          title: title,
          body: sendPdfToModel ? pasted : storedBody,
          objectives: learningObjectives,
          pdfBytes: pdfBytes,
          pdfFilename: pdfFilename,
        );
        aligned = extracted.topics
            .map(
              (e) => (
                title: e.title,
                objective: e.objective,
                questions: e.questions,
              ),
            )
            .toList();
        summary = extracted.summary;
        keyIdeas = extracted.keyIdeas;
        tables = extracted.tables;
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

    if (tables.isEmpty) {
      tables = parseMarkdownTables(storedBody);
    }
    if (keyIdeas.isEmpty) {
      keyIdeas = aligned
          .map((e) => LectureKeyIdea(title: e.title))
          .toList();
    }
    if ((summary ?? '').trim().isEmpty && aligned.isNotEmpty) {
      summary =
          'This lecture covers ${aligned.map((e) => e.title).take(8).join(', ')}'
          '${aligned.length > 8 ? '…' : ''}.';
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
      if (summary != null && summary.trim().isNotEmpty) 'summary': summary,
      'keyIdeas': keyIdeas.map((e) => e.toMap()).toList(),
      'tables': tables.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final id in topicIds) {
      await _topics.doc(id).update({'sourceLectureId': doc.id});
    }

    return doc.id;
  }

  Future<void> linkAssessment(String lectureId, String assessmentId) async {
    if (lectureId.trim().isEmpty || assessmentId.trim().isEmpty) return;
    await _lectures.doc(lectureId).set({
      'assessmentIds': FieldValue.arrayUnion([assessmentId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlinkAssessment(String lectureId, String assessmentId) async {
    if (lectureId.trim().isEmpty || assessmentId.trim().isEmpty) return;
    await _lectures.doc(lectureId).set({
      'assessmentIds': FieldValue.arrayRemove([assessmentId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
