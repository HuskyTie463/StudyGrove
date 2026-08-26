import '../models/models.dart';
import 'math_format.dart';

enum ListenVibe {
  calmCoach,
  gardenWalk,
  examDrill,
  storytime,
  radioHost,
}

extension ListenVibeX on ListenVibe {
  String get label => switch (this) {
        ListenVibe.calmCoach => 'Calm coach',
        ListenVibe.gardenWalk => 'Garden walk',
        ListenVibe.examDrill => 'Exam drill',
        ListenVibe.storytime => 'Storytime',
        ListenVibe.radioHost => 'Radio host',
      };

  String get hint => switch (this) {
        ListenVibe.calmCoach => 'Slow, grounded recap',
        ListenVibe.gardenWalk => 'Unhurried outdoor pace',
        ListenVibe.examDrill => 'Tight cues, then pause',
        ListenVibe.storytime => 'Narrative through the lecture',
        ListenVibe.radioHost => 'Warm conversational pass',
      };

  double get speechRate => switch (this) {
        ListenVibe.calmCoach => 0.38,
        ListenVibe.gardenWalk => 0.36,
        ListenVibe.examDrill => 0.48,
        ListenVibe.storytime => 0.40,
        ListenVibe.radioHost => 0.44,
      };

  double get pitch => switch (this) {
        ListenVibe.calmCoach => 0.95,
        ListenVibe.gardenWalk => 0.92,
        ListenVibe.examDrill => 1.05,
        ListenVibe.storytime => 1.0,
        ListenVibe.radioHost => 1.08,
      };
}

enum QuizKind { multipleChoice, shortRecall, trueFalse }

class QuizItem {
  const QuizItem({
    required this.id,
    required this.prompt,
    required this.kind,
    required this.explanation,
    required this.topicTitle,
    this.options = const [],
    this.correctIndex,
    this.expectedKeywords = const [],
    this.sourceExcerpt,
    this.objective,
  });

  final String id;
  final String prompt;
  final QuizKind kind;
  final List<String> options;
  final int? correctIndex;
  final List<String> expectedKeywords;
  final String explanation;
  final String topicTitle;
  final String? sourceExcerpt;
  final String? objective;
}

class FlashCard {
  const FlashCard({
    required this.topicId,
    required this.front,
    required this.back,
    this.excerpt,
    this.objective,
  });

  final String topicId;
  final String front;
  final String back;
  final String? excerpt;
  final String? objective;
}

class ComparePair {
  const ComparePair({
    required this.left,
    required this.right,
    required this.prompt,
  });

  final ReviewTopic left;
  final ReviewTopic right;
  final String prompt;
}

/// One condition flipped. Student says what still holds and what collapses.
class KnobItem {
  const KnobItem({
    required this.id,
    required this.topicTitle,
    required this.mechanism,
    required this.changedCondition,
    required this.stillHolds,
    required this.collapses,
    this.sourceExcerpt,
    this.objective,
  });

  final String id;
  final String topicTitle;
  final String mechanism;
  final String changedCondition;
  final String stillHolds;
  final String collapses;
  final String? sourceExcerpt;
  final String? objective;
}

/// Same relational structure, new surface. Student maps and refuses false maps.
class TransferItem {
  const TransferItem({
    required this.id,
    required this.topicTitle,
    required this.originalSituation,
    required this.newStory,
    required this.correspondences,
    required this.doNotMap,
    this.sourceExcerpt,
    this.objective,
  });

  final String id;
  final String topicTitle;
  final String originalSituation;
  final String newStory;
  final List<String> correspondences;
  final List<String> doNotMap;
  final String? sourceExcerpt;
  final String? objective;
}

/// Builds retrieval practice from stored lectures/topics. Not a model.
class ConsolidationEngine {
  const ConsolidationEngine();

  List<LectureNote> lecturesForSubject(
    List<LectureNote> lectures,
    Subject? subject,
  ) {
    if (subject == null) return lectures;
    return lectures
        .where(
          (l) =>
              l.subjectId == subject.id ||
              (l.course != null &&
                  (l.course == subject.name ||
                      l.course == subject.code ||
                      l.course == subject.label)),
        )
        .toList();
  }

  List<ReviewTopic> topicsForSubject(
    List<ReviewTopic> topics,
    Subject? subject,
  ) {
    if (subject == null) return topics;
    return topics
        .where(
          (t) =>
              t.subjectId == subject.id ||
              (t.course != null &&
                  (t.course == subject.name ||
                      t.course == subject.code ||
                      t.course == subject.label)),
        )
        .toList();
  }

  List<ReviewTopic> topicsForLecture(
    List<ReviewTopic> topics,
    LectureNote lecture,
  ) {
    final ids = lecture.topicIds.toSet();
    return topics
        .where(
          (t) => t.sourceLectureId == lecture.id || ids.contains(t.id),
        )
        .toList();
  }

  List<String> allObjectives(List<LectureNote> lectures) {
    final out = <String>[];
    for (final l in lectures) {
      for (final o in l.learningObjectives) {
        if (o.trim().isNotEmpty && !out.contains(o.trim())) {
          out.add(o.trim());
        }
      }
    }
    return out;
  }

  List<QuizItem> buildQuiz({
    required List<ReviewTopic> topics,
    required List<LectureNote> lectures,
    bool interleaved = false,
    int maxItems = 12,
  }) {
    final items = <QuizItem>[];
    final pool = [...topics];
    if (interleaved) pool.shuffle();

    for (var i = 0; i < pool.length && items.length < maxItems; i++) {
      final topic = pool[i];
      final excerpt = topic.questions
              .map((q) => q.sourceExcerpt)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .firstOrNull ??
          _excerptFromLectures(lectures, topic.title);
      final objective = topic.learningObjective;

      if (pool.length >= 3 && i % 3 == 0) {
        final distractors = pool
            .where((t) => t.id != topic.id)
            .map((t) => t.title)
            .toList()
          ..shuffle();
        final options = [topic.title, ...distractors.take(3)]..shuffle();
        items.add(
          QuizItem(
            id: '${topic.id}-mcq',
            prompt: excerpt != null && excerpt.length > 24
                ? 'Which idea is this lecture passage pointing at?\n\n“${_clip(excerpt, 160)}”'
                : 'Which idea belongs with this subject, and what does it actually mean?',
            kind: QuizKind.multipleChoice,
            options: options,
            correctIndex: options.indexOf(topic.title),
            explanation: _explain(topic, excerpt, objective),
            topicTitle: topic.title,
            sourceExcerpt: excerpt,
            objective: objective,
          ),
        );
        continue;
      }

      if (i % 3 == 1 && excerpt != null) {
        final truth = i.isEven;
        final prompt = truth
            ? 'True or false: ${topic.title} is a real idea from these lectures, and it is used when the notes describe that situation.'
            : 'True or false: ${topic.title} is unrelated to this subject and can be ignored for these lectures.';
        items.add(
          QuizItem(
            id: '${topic.id}-tf',
            prompt: prompt,
            kind: QuizKind.trueFalse,
            options: const ['True', 'False'],
            correctIndex: truth ? 0 : 1,
            explanation: _explain(topic, excerpt, objective),
            topicTitle: topic.title,
            sourceExcerpt: excerpt,
            objective: objective,
          ),
        );
        continue;
      }

      final q = topic.questions.isNotEmpty ? topic.questions.first : null;
      items.add(
        QuizItem(
          id: '${topic.id}-sa',
          prompt: q?.prompt ??
              'In your own words, what does ${topic.title} mean, and when would you use it?',
          kind: QuizKind.shortRecall,
          expectedKeywords: _keywords(topic.title, excerpt),
          explanation: _explain(topic, excerpt ?? q?.sourceExcerpt, objective),
          topicTitle: topic.title,
          sourceExcerpt: excerpt ?? q?.sourceExcerpt,
          objective: objective,
        ),
      );
    }
    return items;
  }

  bool gradeShort(QuizItem item, String answer) {
    final text = answer.toLowerCase();
    if (text.trim().length < 8) return false;
    var hits = 0;
    for (final k in item.expectedKeywords) {
      if (k.length >= 4 && text.contains(k.toLowerCase())) hits++;
    }
    return hits >= (item.expectedKeywords.length <= 2 ? 1 : 2);
  }

  List<FlashCard> buildFlashcards(List<ReviewTopic> topics) {
    return topics.map((t) {
      final excerpt = t.questions
          .map((q) => q.sourceExcerpt)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .firstOrNull;
      final storedQ = t.questions
          .map((q) => q.prompt)
          .where((p) => p.trim().length > 8)
          .firstOrNull;
      final storedA = t.questions
              .map((q) => q.answer)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .firstOrNull ??
          excerpt ??
          'Say what ${t.title} means in a sentence, then when you would reach for it.';
      final front = storedQ ??
          'What does this idea mean, and when do you use it?\n\n${t.title}';
      final back = storedA.contains(t.title)
          ? storedA
          : '${t.title}\n\n$storedA';
      return FlashCard(
        topicId: t.id,
        front: front,
        back: back,
        excerpt: excerpt,
        objective: t.learningObjective,
      );
    }).toList();
  }

  List<String> elaborativePrompts(List<ReviewTopic> topics) {
    return topics
        .take(10)
        .map(
          (t) =>
              'Why does ${t.title} matter here? What would go wrong if you ignored it?',
        )
        .toList();
  }

  List<ComparePair> comparisons(List<ReviewTopic> topics) {
    if (topics.length < 2) return const [];
    final pairs = <ComparePair>[];
    for (var i = 0; i + 1 < topics.length && pairs.length < 6; i += 2) {
      pairs.add(
        ComparePair(
          left: topics[i],
          right: topics[i + 1],
          prompt:
              'How do ${topics[i].title} and ${topics[i + 1].title} differ in meaning, and when would you use each?',
        ),
      );
    }
    return pairs;
  }

  /// Spoken-tutor briefing. Keep it short enough for a Realtime session.
  String tutorBriefing({
    required String subjectLabel,
    required List<LectureNote> lectures,
    required List<ReviewTopic> topics,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'You are a live spoken tutor in Study Grove for $subjectLabel. '
      'Talk like a calm human. Short turns. The student may interrupt you — stop immediately when they speak. '
      'They will ask questions, quiz you, or ask you to quiz them. Stay in conversation.',
    );
    buf.writeln(
      'Use only the notes below. If something is not in the notes, say you cannot see it there. '
      'Do not invent facts. After you explain one idea, ask one check question. '
      'Say math in words, never slash fractions like a/b.',
    );
    buf.writeln();
    if (topics.isNotEmpty) {
      buf.writeln('Concepts:');
      for (final t in topics.take(16)) {
        buf.writeln('- ${t.title}');
      }
      buf.writeln();
    }
    if (lectures.isEmpty && topics.isEmpty) {
      buf.writeln('There are no lecture notes yet. Tell the student to add notes in Lecture Lab.');
    } else {
      buf.writeln('Notes:');
      var used = buf.length;
      for (final l in lectures.take(6)) {
        final body = l.body.trim();
        if (body.isEmpty) continue;
        final piece = '## ${l.title}\n${_clip(body, 2200)}\n\n';
        if (used + piece.length > 12000) break;
        buf.write(piece);
        used += piece.length;
      }
    }
    return buf.toString();
  }

  List<KnobItem> buildKnobItems(
    List<ReviewTopic> topics,
    List<LectureNote> lectures,
  ) {
    final pool = _topicsOrLectures(topics, lectures);
    return pool.take(8).map((t) {
      final excerpt = _topicExcerpt(t, lectures);
      final mechanism = t.questions
              .map((q) => q.answer)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .firstOrNull ??
          excerpt ??
          'Recall what ${t.title} means and which condition it depends on.';
      return KnobItem(
        id: '${t.id}-knob',
        topicTitle: t.title,
        mechanism: mechanism,
        changedCondition:
            'Flip one condition ${t.title} depends on. What if that condition no longer held?',
        stillHolds: excerpt != null
            ? 'Keep only the parts of ${t.title} that do not use the flipped condition. From your notes: “${_clip(excerpt, 180)}”'
            : 'Re-read the lecture on ${t.title}. Keep claims that do not need the original condition.',
        collapses:
            'Any use, prediction, or formula that assumed the original condition no longer applies. Say what would go wrong if you still treated it as ${t.title}.',
        sourceExcerpt: excerpt,
        objective: t.learningObjective,
      );
    }).toList();
  }

  List<TransferItem> buildTransferItems(
    List<ReviewTopic> topics,
    List<LectureNote> lectures,
  ) {
    final pool = _topicsOrLectures(topics, lectures);
    return pool.take(8).map((t) {
      final excerpt = _topicExcerpt(t, lectures);
      final original = excerpt ??
          'The lecture situation in which ${t.title} is used.';
      return TransferItem(
        id: '${t.id}-transfer',
        topicTitle: t.title,
        originalSituation: original,
        newStory:
            'Put the same structure as ${t.title} into a different setting — another system in this subject, or a careful everyday analogue the notes would still license. Do not add facts the lectures never support.',
        correspondences: [
          'The core process in ${t.title} ↔ the same process in the new setting',
          'The constraint that makes ${t.title} apply ↔ the matching constraint in the new setting',
        ],
        doNotMap: [
          'Surface dressing (names, units, story details) the notes never treat as part of the mechanism',
          'Any extra cause you invented that is not in the lecture',
        ],
        sourceExcerpt: excerpt,
        objective: t.learningObjective,
      );
    }).toList();
  }

  String listenScript({
    required ListenVibe vibe,
    required String subjectLabel,
    required List<LectureNote> lectures,
    required List<ReviewTopic> topics,
  }) {
    final concepts = topics.map((t) => t.title).take(12).toList();
    final objectives = allObjectives(lectures);
    final intro = switch (vibe) {
      ListenVibe.calmCoach =>
        'Settle in. This is a calm recap of $subjectLabel. You do not need to take notes — just listen, then pause if a concept snags.',
      ListenVibe.gardenWalk =>
        'Imagine walking the greenhouse path while we pass through $subjectLabel. Unhurried. One plant, then the next.',
      ListenVibe.examDrill =>
        'Exam drill for $subjectLabel. I will name a concept, leave a beat for you to retrieve it, then give the lecture’s cue.',
      ListenVibe.storytime =>
        'Here is the story of this $subjectLabel lecture arc — beginning, middle, and what you should be able to do by the end.',
      ListenVibe.radioHost =>
        'Welcome back. Today on the subject hour: $subjectLabel, pulled straight from your notes — no extra garnish.',
    };

    final buf = StringBuffer('$intro\n\n');
    if (objectives.isNotEmpty) {
      buf.writeln('By the end you should be able to:');
      for (final o in objectives.take(8)) {
        buf.writeln(o);
      }
      buf.writeln();
    }
    if (concepts.isEmpty && lectures.isEmpty) {
      buf.writeln(
        'There are no lecture notes for this subject yet. Add a lecture in Lecture Lab, then come back.',
      );
      return buf.toString();
    }
    for (var i = 0; i < topics.length && i < 10; i++) {
      final t = topics[i];
      final excerpt = t.questions
              .map((q) => q.sourceExcerpt)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .firstOrNull ??
          '';
      if (vibe == ListenVibe.examDrill) {
        buf.writeln('Retrieve: ${t.title}.');
        buf.writeln('Pause.');
        if (excerpt.isNotEmpty) buf.writeln(MathFormat.forSpeech(excerpt));
      } else {
        buf.writeln('Next concept: ${t.title}.');
        if (t.learningObjective != null) {
          buf.writeln('This serves the objective: ${t.learningObjective}.');
        }
        if (excerpt.isNotEmpty) buf.writeln(MathFormat.forSpeech(excerpt));
      }
      buf.writeln();
    }
    for (final l in lectures.take(2)) {
      if (l.body.trim().isEmpty) continue;
      buf.writeln('From the lecture titled ${l.title}.');
      buf.writeln(MathFormat.forSpeech(_clip(l.body, 500)));
      buf.writeln();
    }
    buf.writeln(
      vibe == ListenVibe.examDrill
          ? 'That is the drill. Replay the ones you blanked on.'
          : 'That is the pass. If one idea felt foggy, open flashcards or the quiz next.',
    );
    return buf.toString();
  }

  List<ReviewTopic> _topicsOrLectures(
    List<ReviewTopic> topics,
    List<LectureNote> lectures,
  ) {
    if (topics.isNotEmpty) return topics;
    return lectures
        .where((l) => l.title.trim().isNotEmpty || l.body.trim().isNotEmpty)
        .map(
          (l) => ReviewTopic(
            id: l.id,
            title: l.title.trim().isEmpty ? 'Untitled lecture' : l.title,
            subjectId: l.subjectId,
            sourceLectureId: l.id,
            questions: [
              RecallQuestion(
                id: '${l.id}-body',
                prompt: l.title,
                sourceExcerpt: l.body.trim().isEmpty ? null : _clip(l.body, 280),
              ),
            ],
          ),
        )
        .toList();
  }

  String? _topicExcerpt(ReviewTopic topic, List<LectureNote> lectures) {
    return topic.questions
            .map((q) => q.sourceExcerpt)
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .firstOrNull ??
        _excerptFromLectures(lectures, topic.title);
  }

  String? _excerptFromLectures(List<LectureNote> lectures, String topic) {
    final key = topic.toLowerCase().split(' ').first;
    for (final l in lectures) {
      final idx = l.body.toLowerCase().indexOf(key);
      if (idx < 0) continue;
      final start = (idx - 40).clamp(0, l.body.length);
      final end = (idx + topic.length + 80).clamp(0, l.body.length);
      return l.body.substring(start, end).trim();
    }
    return null;
  }

  List<String> _keywords(String title, String? excerpt) {
    final words = <String>{};
    for (final w in title.split(RegExp(r'\W+'))) {
      if (w.length >= 4) words.add(w.toLowerCase());
    }
    if (excerpt != null) {
      for (final w in excerpt.split(RegExp(r'\W+'))) {
        if (w.length >= 5) words.add(w.toLowerCase());
      }
    }
    return words.take(8).toList();
  }

  String _explain(ReviewTopic topic, String? excerpt, String? objective) {
    final bits = <String>[];
    if (objective != null) {
      bits.add('This maps to the learning objective: $objective.');
    }
    if (excerpt != null && excerpt.trim().isNotEmpty) {
      bits.add('From your notes: “${_clip(excerpt, 220)}”');
    } else {
      bits.add(
        'Re-read the lecture passage on ${topic.title}. The answer should come from that source, not from memory of a summary.',
      );
    }
    return bits.join(' ');
  }

  String _clip(String s, int n) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= n) return t;
    return '${t.substring(0, n)}…';
  }
}
