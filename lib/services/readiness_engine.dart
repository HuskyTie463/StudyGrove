import '../models/models.dart';

enum ReadinessState {
  onTrack,
  needsAttention,
  timeIsTight,
  missingInformation,
}

extension ReadinessStateX on ReadinessState {
  String get calmLabel => switch (this) {
        ReadinessState.onTrack => 'On track',
        ReadinessState.needsAttention => 'Needs attention',
        ReadinessState.timeIsTight => 'Time is tight',
        ReadinessState.missingInformation => 'Missing information',
      };
}

class ReadinessEvidence {
  const ReadinessEvidence({
    required this.state,
    required this.summary,
    required this.factors,
    required this.estimatedPrepRemainingMinutes,
    required this.priorityScore,
  });

  final ReadinessState state;
  final String summary;
  final List<String> factors;
  /// Null when prep estimate is unknown.
  final int? estimatedPrepRemainingMinutes;
  final double priorityScore;
}

class AssessmentReadinessEngine {
  const AssessmentReadinessEngine();

  ReadinessEvidence explain(
    Assessment a, {
    DateTime? now,
    int? availableMinutesToday,
  }) {
    final days = a.daysUntilDue;
    final factors = <String>[];
    var missing = 0;

    if (a.weightPercent == null) {
      missing++;
      factors.add('Weight not set — importance is unclear.');
    } else {
      factors.add('Weight ${a.weightPercent!.round()}% of course.');
    }

    if (a.estimatedPrepMinutes == null) {
      missing++;
      factors.add('Estimated prep time not set.');
    } else {
      final remaining = _remainingPrep(a);
      factors.add(
        remaining == 0
            ? 'Checklist suggests prep tasks are complete.'
            : 'About $remaining min of prep still estimated.',
      );
    }

    if (a.confidence == null) {
      missing++;
      factors.add('Confidence not recorded yet.');
    } else {
      final pct = (a.confidence! * 100).round();
      factors.add('Self-reported confidence $pct%.');
    }

    factors.add(
      a.subtasks.isEmpty
          ? 'No prep tasks linked yet.'
          : '${a.subtasks.where((s) => s.done).length}/${a.subtasks.length} prep tasks done.',
    );

    if (a.linkedTopicIds.isEmpty) {
      factors.add('No recall topics linked.');
    } else {
      factors.add('${a.linkedTopicIds.length} recall topic(s) linked.');
    }

    factors.add(a.dueLabel);

    final remainingPrep = _remainingPrep(a);
    ReadinessState state;

    if (missing >= 2 && days > 3) {
      state = ReadinessState.missingInformation;
    } else if (days < 0) {
      state = ReadinessState.timeIsTight;
      factors.add('Past due — prioritise submission/check.');
    } else if (days <= 2 && (remainingPrep ?? 90) > 60) {
      state = ReadinessState.timeIsTight;
    } else if (a.progress < 0.4 && days <= 7) {
      state = ReadinessState.needsAttention;
    } else if (a.confidence != null && a.confidence! < 0.4 && days <= 10) {
      state = ReadinessState.needsAttention;
    } else if (missing >= 2) {
      state = ReadinessState.missingInformation;
    } else {
      state = ReadinessState.onTrack;
    }

    if (availableMinutesToday != null &&
        remainingPrep != null &&
        remainingPrep > availableMinutesToday &&
        days <= 3) {
      state = ReadinessState.timeIsTight;
      factors.add(
        'Today has ~$availableMinutesToday usable min vs ~$remainingPrep needed.',
      );
    }

    final summary = switch (state) {
      ReadinessState.onTrack =>
        'Evidence suggests preparation is progressing relative to time left.',
      ReadinessState.needsAttention =>
        'Coverage, tasks or confidence suggest more focused prep soon.',
      ReadinessState.timeIsTight =>
        'Time left is short relative to remaining prep evidence.',
      ReadinessState.missingInformation =>
        'Add weight, prep estimate or confidence so Study Grove can advise better.',
    };

    final priority = _priorityScore(a, state, remainingPrep);
    return ReadinessEvidence(
      state: state,
      summary: summary,
      factors: factors,
      estimatedPrepRemainingMinutes: remainingPrep,
      priorityScore: priority,
    );
  }

  int? _remainingPrep(Assessment a) {
    if (a.estimatedPrepMinutes != null) {
      final doneFraction = a.subtasks.isEmpty ? 0.0 : a.progress;
      return (a.estimatedPrepMinutes! * (1 - doneFraction)).round().clamp(0, 100000);
    }
    if (a.subtasks.isNotEmpty) {
      // Rough fallback: 25 min per open subtask — labelled as estimate from tasks only.
      return a.openSubtaskCount * 25;
    }
    return null;
  }

  double _priorityScore(
    Assessment a,
    ReadinessState state,
    int? remainingPrep,
  ) {
    final days = a.daysUntilDue.toDouble();
    final urgency = days <= 0
        ? 100.0
        : (40 / (days + 1)).clamp(0, 40);
    final weight = (a.weightPercent ?? 10) * 0.35;
    final prepPressure = ((remainingPrep ?? 60) / 30).clamp(0, 20);
    final stateBoost = switch (state) {
      ReadinessState.timeIsTight => 25.0,
      ReadinessState.needsAttention => 15.0,
      ReadinessState.missingInformation => 8.0,
      ReadinessState.onTrack => 0.0,
    };
    final progressRelief = a.progress * 10;
    return urgency + weight + prepPressure + stateBoost - progressRelief;
  }

  Assessment? mostImportant(
    List<Assessment> assessments, {
    DateTime? now,
  }) {
    final active = assessments.where((a) => a.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) {
      final ea = explain(a, now: now);
      final eb = explain(b, now: now);
      return eb.priorityScore.compareTo(ea.priorityScore);
    });
    return active.first;
  }

  String bestNextAction(Assessment a, ReadinessEvidence evidence) {
    final open = a.subtasks.where((s) => !s.done).toList();
    if (open.isNotEmpty) {
      return 'Work on: ${open.first.title}';
    }
    if (a.linkedTopicIds.isNotEmpty) {
      return 'Run a short active-recall on a linked topic';
    }
    if (a.estimatedPrepMinutes == null || a.weightPercent == null) {
      return 'Fill in prep estimate and weight so planning can tighten';
    }
    if (evidence.state == ReadinessState.timeIsTight) {
      return 'Protect a focused block before the next commitment';
    }
    return 'Add a prep checklist item or schedule a review window';
  }
}
