import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'consolidation_engine.dart';
import 'math_format.dart';
import 'study_ai_proxy.dart';
import 'study_ai_settings.dart';

class StudyAiException implements Exception {
  StudyAiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudyAiExtractedTopic {
  const StudyAiExtractedTopic({
    required this.title,
    this.objective,
    this.questions = const [],
  });

  final String title;
  final String? objective;
  final List<RecallQuestion> questions;
}

/// Calls the Study Grove AI proxy (or a user-supplied key). Notes stay on
/// the device except for the request body sent to the model.
class StudyAiClient {
  StudyAiClient._();
  static final instance = StudyAiClient._();

  Future<bool> get isConfigured async {
    if (!studyAiSettings.ready) await studyAiSettings.load();
    return studyAiSettings.hasKey;
  }

  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 3500,
  }) async {
    if (!studyAiSettings.ready) await studyAiSettings.load();
    if (!studyAiSettings.hasKey) {
      throw StudyAiException(
        'Study AI needs the proxy running, or a custom key in Settings.',
      );
    }
    return switch (studyAiSettings.provider) {
      StudyAiProvider.openai => _openai(
          system: system,
          user: user,
          maxTokens: maxTokens,
        ),
      StudyAiProvider.anthropic => _anthropic(
          system: system,
          user: user,
          maxTokens: maxTokens,
        ),
    };
  }

  /// Reads a PDF or image through the provider. Anthropic accepts native
  /// documents; OpenAI gets a local-text fallback via the caller.
  Future<String> transcribeFile({
    required List<int> bytes,
    required String filename,
    required String mediaType,
  }) async {
    if (!studyAiSettings.ready) await studyAiSettings.load();
    if (!studyAiSettings.hasKey) {
      throw StudyAiException(
        'Study AI needs the proxy running, or a custom key in Settings.',
      );
    }
    if (bytes.length > 18 * 1024 * 1024) {
      throw StudyAiException(
        '$filename is too large to send. Split it or paste the notes.',
      );
    }
    final b64 = base64Encode(bytes);
    final prompt =
        'Extract the full lecture text from this file ($filename). '
        'Keep headings and slide order. Do not summarise. '
        'If a page is a diagram, briefly describe it in square brackets. '
        'Write every formula in LaTeX with \$...\$ and stacked fractions '
        r'as \frac{numerator}{denominator}, never slash form like a/b. '
        'Name what each symbol means in words.';
    if (studyAiSettings.provider == StudyAiProvider.openai) {
      throw StudyAiException(
        'PDF and image files work with Anthropic. Switch provider in Settings, or paste the text.',
      );
    }
    final isPdf = mediaType == 'application/pdf';
    final block = <String, dynamic>{
      'type': isPdf ? 'document' : 'image',
      'source': {
        'type': 'base64',
        'media_type': mediaType,
        'data': b64,
      },
    };
    return _anthropic(
      system:
          'You transcribe lecture materials into clean study notes. Use only what is in the file.',
      user: [
        block,
        {'type': 'text', 'text': prompt},
      ],
      maxTokens: 8000,
    );
  }

  Future<List<StudyAiExtractedTopic>> extractLecture({
    required String title,
    required String body,
    List<String> objectives = const [],
    List<int>? pdfBytes,
    String? pdfFilename,
  }) async {
    final clipped = body.length > 12000 ? '${body.substring(0, 12000)}…' : body;
    final objBlock = objectives.isEmpty
        ? 'No learning objectives were given. Extract the most testable concepts.'
        : 'Align every topic to one of these learning objectives. Drop material that does not serve them:\n${objectives.map((o) => '- $o').join('\n')}';
    final jsonShape = '''
Return JSON of the form:
{"topics":[{"title":"concept name in words","objective":"matching objective or null","questions":[{"prompt":"conceptual question in words","answer":"explanation in words, with LaTeX formulas if needed","sourceExcerpt":"short quote from notes"}]}]}
Give 4–10 topics. Titles are ideas ("Conservation of energy in a closed system"), not symbols.
Each topic 2–3 questions that test meaning, use, and contrast — not "what is x".
''';
    final pdf = pdfBytes;
    final hasPdf = pdf != null && pdf.isNotEmpty;
    final hasNotes = body.trim().isNotEmpty;
    if (!hasPdf && !hasNotes) {
      throw StudyAiException('Add notes or a PDF to extract.');
    }
    final system = hasPdf
        ? 'You extract study concepts from the attached lecture PDF'
            '${hasNotes ? ' and any pasted notes' : ''}. Use only that material. '
            'If something is not in the source, omit it. Return JSON only. '
            '$mathAndConceptInstructions'
        : 'You extract study concepts from lecture notes. Use only the notes. '
            'If something is not in the notes, omit it. Return JSON only. '
            '$mathAndConceptInstructions';

    late final String raw;
    if (pdf != null &&
        pdf.isNotEmpty &&
        studyAiSettings.provider == StudyAiProvider.anthropic) {
      if (!studyAiSettings.ready) await studyAiSettings.load();
      if (!studyAiSettings.hasKey) {
        throw StudyAiException(
          'Study AI needs the proxy running, or a custom key in Settings.',
        );
      }
      if (pdf.length > 18 * 1024 * 1024) {
        throw StudyAiException(
          '${pdfFilename ?? 'That PDF'} is too large to send. Split it or paste the notes.',
        );
      }
      final notesBlock = hasNotes
          ? 'Also consider these pasted notes:\n$clipped\n'
          : 'The lecture is in the attached PDF. Use only that document.\n';
      raw = await _anthropic(
        system: system,
        user: [
          {
            'type': 'document',
            'source': {
              'type': 'base64',
              'media_type': 'application/pdf',
              'data': base64Encode(pdf),
            },
          },
          {
            'type': 'text',
            'text': '''
Lecture title: $title
File: ${pdfFilename ?? 'lecture.pdf'}

$objBlock

$notesBlock
$jsonShape
''',
          },
        ],
        maxTokens: 6000,
      );
    } else {
      if (!hasNotes) {
        throw StudyAiException(
          hasPdf
              ? 'PDF files work with Anthropic. Switch provider in Settings, or paste the notes.'
              : 'Add notes or a PDF to extract.',
        );
      }
      raw = await complete(
        system: system,
        user: '''
Lecture title: $title

$objBlock

Notes:
$clipped

$jsonShape
''',
      );
    }
    final map = _asJsonMap(raw);
    final list = (map['topics'] as List?) ?? const [];
    final out = <StudyAiExtractedTopic>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! Map) continue;
      final m = Map<String, dynamic>.from(list[i] as Map);
      final titleOut = (m['title'] as String?)?.trim() ?? '';
      if (titleOut.isEmpty) continue;
      final qsRaw = (m['questions'] as List?) ?? const [];
      final qs = <RecallQuestion>[];
      for (var q = 0; q < qsRaw.length; q++) {
        if (qsRaw[q] is! Map) continue;
        final qm = Map<String, dynamic>.from(qsRaw[q] as Map);
        qs.add(
          RecallQuestion(
            id: 'ai$q',
            prompt: (qm['prompt'] as String?) ?? '',
            answer: qm['answer'] as String?,
            sourceExcerpt: qm['sourceExcerpt'] as String?,
            unsupported: (qm['sourceExcerpt'] as String?) == null,
          ),
        );
      }
      out.add(
        StudyAiExtractedTopic(
          title: titleOut,
          objective: (m['objective'] as String?)?.trim(),
          questions: qs,
        ),
      );
    }
    if (out.isEmpty) {
      throw StudyAiException('The model returned no usable topics.');
    }
    return out;
  }

  Future<List<QuizItem>> generateQuiz({
    required List<ReviewTopic> topics,
    required List<LectureNote> lectures,
    bool interleaved = false,
  }) async {
    final notes = lectures.take(4).map((l) {
      final body = l.body.length > 3500 ? '${l.body.substring(0, 3500)}…' : l.body;
      return '## ${l.title}\n$body';
    }).join('\n\n');
    final concepts = topics.take(16).map((t) {
      final obj = t.learningObjective == null ? '' : ' (objective: ${t.learningObjective})';
      return '- ${t.title}$obj';
    }).join('\n');
    final raw = await complete(
      system:
          'You write graded retrieval quizzes from the student\'s notes only. '
          'Do not invent facts. JSON only. $mathAndConceptInstructions',
      user: '''
${interleaved ? 'Interleave items across concepts.' : 'Group related items, still mix formats.'}

Concepts:
$concepts

Notes:
$notes

Return JSON:
{"items":[{"prompt":"...","kind":"mcq"|"tf"|"short","options":["full concept statement","..."],"correctIndex":0,"expectedKeywords":["..."],"explanation":"why, in words, quoting the notes","topicTitle":"...","sourceExcerpt":"...","objective":null}]}
8–12 items. Ask what the idea means, when to use it, or what would change if a condition changed.
Do not ask "what is x". MCQ options are full statements, not A/B/C letters or bare formulas.
For tf, options must be ["True","False"]. For short, options can be [].
''',
    );
    final map = _asJsonMap(raw);
    final list = (map['items'] as List?) ?? const [];
    final items = <QuizItem>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! Map) continue;
      final m = Map<String, dynamic>.from(list[i] as Map);
      final kindStr = (m['kind'] as String?) ?? 'short';
      final kind = switch (kindStr) {
        'mcq' => QuizKind.multipleChoice,
        'tf' => QuizKind.trueFalse,
        _ => QuizKind.shortRecall,
      };
      final options = ((m['options'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      items.add(
        QuizItem(
          id: 'ai-$i',
          prompt: (m['prompt'] as String?) ?? '',
          kind: kind,
          options: options,
          correctIndex: (m['correctIndex'] as num?)?.toInt(),
          expectedKeywords: ((m['expectedKeywords'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          explanation: (m['explanation'] as String?) ?? '',
          topicTitle: (m['topicTitle'] as String?) ?? '',
          sourceExcerpt: m['sourceExcerpt'] as String?,
          objective: m['objective'] as String?,
        ),
      );
    }
    if (items.isEmpty) {
      throw StudyAiException('The model returned no quiz items.');
    }
    return items;
  }

  Future<String> generateListenScript({
    required ListenVibe vibe,
    required String subjectLabel,
    required List<LectureNote> lectures,
    required List<ReviewTopic> topics,
  }) async {
    final notes = lectures.take(4).map((l) {
      final body = l.body.length > 3000 ? '${l.body.substring(0, 3000)}…' : l.body;
      return '## ${l.title}\n$body';
    }).join('\n\n');
    final concepts = topics.take(16).map((t) => '- ${t.title}').join('\n');
    return complete(
      system:
          'You write spoken study scripts from the student\'s notes only. '
          'No stage directions. No invented content. Plain paragraphs for text-to-speech. '
          'Talk in concepts and meaning, not bare letters. '
          'Say fractions as "numerator over denominator", never "a slash b".',
      user: '''
Subject: $subjectLabel
Vibe: ${vibe.label} — ${vibe.hint}
Length: about 4–7 minutes spoken.

Concepts:
$concepts

Notes:
$notes

Write the full script now.
''',
      maxTokens: 2500,
    );
  }

  Future<List<KnobItem>> generateKnobItems({
    required List<ReviewTopic> topics,
    required List<LectureNote> lectures,
  }) async {
    final notes = lectures.take(4).map((l) {
      final body = l.body.length > 3500 ? '${l.body.substring(0, 3500)}…' : l.body;
      return '## ${l.title}\n$body';
    }).join('\n\n');
    final concepts = topics.take(16).map((t) {
      final obj =
          t.learningObjective == null ? '' : ' (objective: ${t.learningObjective})';
      return '- ${t.title}$obj';
    }).join('\n');
    final raw = await complete(
      system:
          'You write causal-boundary drills from the student\'s notes only. '
          'Do not invent facts or knobs the notes do not support. JSON only. '
          '$mathAndConceptInstructions',
      user: '''
For each concept, pick ONE real condition, assumption, or constraint from the notes and flip it.
The student must say what still holds and what collapses. That is the study.

Concepts:
$concepts

Notes:
$notes

Return JSON:
{"items":[{"topicTitle":"...","mechanism":"the idea as the notes state it, in words","changedCondition":"one concrete knob flipped, grounded in the notes","stillHolds":"what remains true and why, from the notes","collapses":"what breaks, fails, or no longer applies, and why","sourceExcerpt":"short quote from the notes","objective":null}]}
4–8 items. Skip a concept if the notes give no real condition to flip.
changedCondition is a specific "what if…" not "what if things were different".
stillHolds and collapses must not contradict the notes.
''',
    );
    final map = _asJsonMap(raw);
    final list = (map['items'] as List?) ?? const [];
    final items = <KnobItem>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! Map) continue;
      final m = Map<String, dynamic>.from(list[i] as Map);
      final title = (m['topicTitle'] as String?)?.trim() ?? '';
      final condition = (m['changedCondition'] as String?)?.trim() ?? '';
      if (title.isEmpty || condition.isEmpty) continue;
      items.add(
        KnobItem(
          id: 'ai-knob-$i',
          topicTitle: title,
          mechanism: (m['mechanism'] as String?)?.trim() ?? title,
          changedCondition: condition,
          stillHolds: (m['stillHolds'] as String?)?.trim() ?? '',
          collapses: (m['collapses'] as String?)?.trim() ?? '',
          sourceExcerpt: (m['sourceExcerpt'] as String?)?.trim(),
          objective: (m['objective'] as String?)?.trim(),
        ),
      );
    }
    if (items.isEmpty) {
      throw StudyAiException('The model returned no usable knobs.');
    }
    return items;
  }

  Future<List<TransferItem>> generateTransferItems({
    required List<ReviewTopic> topics,
    required List<LectureNote> lectures,
  }) async {
    final notes = lectures.take(4).map((l) {
      final body = l.body.length > 3500 ? '${l.body.substring(0, 3500)}…' : l.body;
      return '## ${l.title}\n$body';
    }).join('\n\n');
    final concepts = topics.take(16).map((t) {
      final obj =
          t.learningObjective == null ? '' : ' (objective: ${t.learningObjective})';
      return '- ${t.title}$obj';
    }).join('\n');
    final raw = await complete(
      system:
          'You write analogical-transfer drills from the student\'s notes only. '
          'Preserve the relational structure in the notes. Do not invent physics, '
          'history, or mechanisms the notes do not license. JSON only. '
          '$mathAndConceptInstructions',
      user: '''
Same engine, new story: keep the deep structure of a lecture idea, change the surface.
The student maps which parts correspond and which must not be mapped.

Concepts:
$concepts

Notes:
$notes

Return JSON:
{"items":[{"topicTitle":"...","originalSituation":"the lecture situation in words","newStory":"a new cover story with the same causal structure","correspondences":["lecture part ↔ new-story part, and why"],"doNotMap":["surface feature that looks similar but must not map, and why"],"sourceExcerpt":"short quote from the notes","objective":null}]}
4–8 items. Skip a concept if you cannot make an analogy the notes would still support.
newStory must not add causes the lectures never treat.
correspondences are structural (roles, constraints, process), not word swaps.
doNotMap must name at least one tempting false mapping.
''',
    );
    final map = _asJsonMap(raw);
    final list = (map['items'] as List?) ?? const [];
    final items = <TransferItem>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! Map) continue;
      final m = Map<String, dynamic>.from(list[i] as Map);
      final title = (m['topicTitle'] as String?)?.trim() ?? '';
      final story = (m['newStory'] as String?)?.trim() ?? '';
      if (title.isEmpty || story.isEmpty) continue;
      items.add(
        TransferItem(
          id: 'ai-transfer-$i',
          topicTitle: title,
          originalSituation:
              (m['originalSituation'] as String?)?.trim() ?? title,
          newStory: story,
          correspondences: _stringList(m['correspondences']),
          doNotMap: _stringList(m['doNotMap']),
          sourceExcerpt: (m['sourceExcerpt'] as String?)?.trim(),
          objective: (m['objective'] as String?)?.trim(),
        ),
      );
    }
    if (items.isEmpty) {
      throw StudyAiException('The model returned no usable transfer items.');
    }
    return items;
  }

  Future<String> _openai({
    required String system,
    required String user,
    required int maxTokens,
  }) async {
    final payload = {
      'model': StudyAiProvider.openai.defaultModel,
      'temperature': 0.3,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };
    late final http.Response res;
    if (studyAiSettings.usesProxy) {
      res = await StudyAiProxy.post(
        '/v1/openai/chat/completions',
        body: payload,
        timeout: const Duration(seconds: 90),
      );
    } else {
      final key = studyAiSettings.apiKey?.trim() ?? '';
      if (key.isEmpty) {
        throw StudyAiException(
          'Study AI needs the proxy running, or a custom key in Settings.',
        );
      }
      res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));
    }
    final data = _decode(res);
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw StudyAiException(_errorFrom(data, res.statusCode));
    }
    final msg = choices.first;
    if (msg is! Map) throw StudyAiException('Unexpected OpenAI response.');
    final content = (msg['message'] as Map?)?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw StudyAiException('OpenAI returned an empty reply.');
    }
    return content;
  }

  Future<String> _anthropic({
    required String system,
    required Object user,
    required int maxTokens,
  }) async {
    final payload = {
      'model': StudyAiProvider.anthropic.defaultModel,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
    };
    final extra = <String, String>{
      if (user is List) 'anthropic-beta': 'pdfs-2024-09-25',
      'anthropic-version': '2023-06-01',
    };
    late final http.Response res;
    if (studyAiSettings.usesProxy) {
      res = await StudyAiProxy.post(
        '/v1/anthropic/messages',
        body: payload,
        extraHeaders: extra,
        timeout: const Duration(seconds: 120),
      );
    } else {
      final key = studyAiSettings.apiKey?.trim() ?? '';
      if (key.isEmpty) {
        throw StudyAiException(
          'Study AI needs the proxy running, or a custom key in Settings.',
        );
      }
      res = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': key,
              'anthropic-version': extra['anthropic-version']!,
              'Content-Type': 'application/json',
              if (extra.containsKey('anthropic-beta'))
                'anthropic-beta': extra['anthropic-beta']!,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));
    }
    final data = _decode(res);
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) {
      throw StudyAiException(_errorFrom(data, res.statusCode));
    }
    final first = content.first;
    if (first is! Map) throw StudyAiException('Unexpected Anthropic response.');
    final text = first['text'];
    if (text is! String || text.trim().isEmpty) {
      throw StudyAiException('Anthropic returned an empty reply.');
    }
    return text;
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw StudyAiException('Provider returned a non-JSON error (${res.statusCode}).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StudyAiException(_errorFrom(data, res.statusCode));
    }
    return data;
  }

  String _errorFrom(Map<String, dynamic> data, int status) {
    final err = data['error'];
    if (err is Map && err['message'] is String) {
      return err['message'] as String;
    }
    if (data['message'] is String) return data['message'] as String;
    if (status == 401) {
      return 'Study AI could not authenticate. Sign in, or check a custom key in Settings.';
    }
    if (status == 429) return 'Rate limited. Try again in a moment.';
    return 'Provider error ($status).';
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _asJsonMap(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw StudyAiException('The model did not return a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
