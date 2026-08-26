import 'dart:math';

enum ChallengeRarity { common, rare, epic }

/// Wheel slice index matches painter order (8 segments).
class RouletteDraw {
  const RouletteDraw({
    required this.sliceIndex,
    required this.primaryLabel,
    required this.title,
    required this.body,
    required this.rarity,
    required this.fortuneLine,
  });

  final int sliceIndex;
  final String primaryLabel;
  final String title;
  final String body;
  final ChallengeRarity rarity;
  final String fortuneLine;

  static const wheelLabels = ['Cards', 'Quiz', 'Notes', 'Practice', 'Feynman', 'Move', 'Wild', 'Combo'];
}

class StudyRouletteEngine {
  StudyRouletteEngine(this._random);
  final Random _random;

  /// Cumulative thresholds on one draw U in [0,1):
  /// Wild, Combo, Move-only, then standard study (with optional exercise finisher).
  static const _pWild = 0.08;
  static const _pCombo = 0.18;
  static const _pMove = 0.30;
  static const _pExerciseOnStandard = 0.42;

  static final _exerciseLines = [
    'Then: 10 bodyweight squats.',
    'Then: 12 incline push-ups (knee push-ups ok).',
    'Then: 30-second forearm plank.',
    'Then: 15 curl-ups or sit-ups.',
    'Then: 20 jumping jacks.',
    'Then: 1-minute brisk walk (inside or outside).',
  ];

  static final _fortuneCalm = [
    'Small steps still move the semester forward.',
    'Consistency beats intensity—show up for this round.',
    'You can swap once if this truly cannot work right now.',
    'Breathe once, start once, you’re allowed to do okay.',
  ];

  static final _fortunePlay = [
    'Boss fight energy: chip its HP down.',
    'RNG believes in you (statistically).',
    'Speedrun this challenge like it owes you loot.',
    'Main-character moment—make it cinematic.',
  ];

  double rotationDelta(int sliceIndex, int fullSpins) {
    final sweep = 2 * pi / 8;
    return fullSpins * 2 * pi + (-sliceIndex * sweep - sweep / 2);
  }

  ChallengeRarity _rollRarity() {
    final u = _random.nextDouble();
    if (u < 0.05) return ChallengeRarity.epic;
    if (u < 0.30) return ChallengeRarity.rare;
    return ChallengeRarity.common;
  }

  String _fortune() {
    final list = _random.nextBool() ? _fortuneCalm : _fortunePlay;
    return list[_random.nextInt(list.length)];
  }

  String _pickExercise() => _exerciseLines[_random.nextInt(_exerciseLines.length)];

  RouletteDraw spin() {
    final rarity = _rollRarity();
    final fortune = _fortune();
    final u = _random.nextDouble();

    if (u < _pWild) {
      return RouletteDraw(
        sliceIndex: 6,
        primaryLabel: 'Wild',
        title: 'Wildcard focus',
        body:
            'Choose the assessment or topic you’re most avoiding. Work on it steadily for ${_minutes(rarity, minM: 12, midM: 18, maxM: 25)} minutes—no tab hopping.',
        rarity: rarity,
        fortuneLine: fortune,
      );
    }

    if (u < _pWild + _pCombo) {
      final study = _studyLine(_pickStudyKind(), rarity);
      return RouletteDraw(
        sliceIndex: 7,
        primaryLabel: 'Combo',
        title: 'Combo round',
        body: '$study\n\n${_pickExercise()}',
        rarity: rarity,
        fortuneLine: fortune,
      );
    }

    if (u < _pWild + _pCombo + _pMove) {
      return RouletteDraw(
        sliceIndex: 5,
        primaryLabel: 'Move',
        title: 'Movement round',
        body:
            '${_pickExercise()}\n\nOptional cool-down: 60 seconds of slow breathing, then one quick mental review (a single term or formula) before you sit back down.',
        rarity: rarity,
        fortuneLine: fortune,
      );
    }

    final kind = _pickStudyKind();
    final addExercise = _random.nextDouble() < _pExerciseOnStandard;
    final study = _studyLine(kind, rarity);
    final sliceIndex = switch (kind) {
      StudyKind.flashcards => 0,
      StudyKind.quiz => 1,
      StudyKind.summary => 2,
      StudyKind.practice => 3,
      StudyKind.feynman => 4,
    };

    return RouletteDraw(
      sliceIndex: sliceIndex,
      primaryLabel: RouletteDraw.wheelLabels[sliceIndex],
      title: _titleFor(kind),
      body: addExercise ? '$study\n\n${_pickExercise()}' : study,
      rarity: rarity,
      fortuneLine: fortune,
    );
  }

  StudyKind _pickStudyKind() => StudyKind.values[_random.nextInt(StudyKind.values.length)];

  String _titleFor(StudyKind k) => switch (k) {
        StudyKind.flashcards => 'Flashcard sprint',
        StudyKind.quiz => 'Quiz yourself',
        StudyKind.summary => 'Summary book',
        StudyKind.practice => 'Practice set',
        StudyKind.feynman => 'Feynman round',
      };

  String _studyLine(StudyKind kind, ChallengeRarity r) {
    return switch (kind) {
      StudyKind.flashcards =>
        'Run ${_count(r, low: 8, mid: 14, high: 22)} flashcards: answer out loud before you flip.',
      StudyKind.quiz =>
        'Write ${_count(r, low: 5, mid: 8, high: 12)} short answers (2–4 sentences each) from memory, then mark yourself honestly.',
      StudyKind.summary =>
        'Add ${_pages(r, low: 0.5, mid: 1, high: 2)} of tight summary notes (bullets + one tiny diagram if it helps).',
      StudyKind.practice =>
        'Do ${_problems(r, low: 3, mid: 5, high: 8)} exam-style questions. Timer: ${_minutes(r, minM: 10, midM: 18, maxM: 28)} minutes.',
      StudyKind.feynman =>
        'Pick one concept and explain it in ${_minutes(r, minM: 3, midM: 5, maxM: 8)} minutes like you’re teaching a friend—record voice memo or talk to the mirror. Write 2 “gap” bullet fixes afterward.',
    };
  }

  int _count(ChallengeRarity r, {required int low, required int mid, required int high}) {
    return switch (r) {
      ChallengeRarity.common => low,
      ChallengeRarity.rare => mid,
      ChallengeRarity.epic => high,
    };
  }

  String _pages(ChallengeRarity r, {required double low, required double mid, required double high}) {
    final v = switch (r) {
      ChallengeRarity.common => low,
      ChallengeRarity.rare => mid,
      ChallengeRarity.epic => high,
    };
    if (v == 0.5) return 'half a page';
    if (v == 1) return '1 page';
    return '${v.toStringAsFixed(0)} pages';
  }

  int _problems(ChallengeRarity r, {required int low, required int mid, required int high}) => _count(r, low: low, mid: mid, high: high);

  int _minutes(ChallengeRarity r, {required int minM, required int midM, required int maxM}) {
    return switch (r) {
      ChallengeRarity.common => minM,
      ChallengeRarity.rare => midM,
      ChallengeRarity.epic => maxM,
    };
  }
}

enum StudyKind { flashcards, quiz, summary, practice, feynman }
