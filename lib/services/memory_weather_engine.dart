import '../models/models.dart';

class MemoryWeatherInsight {
  const MemoryWeatherInsight({
    required this.state,
    required this.headline,
    required this.reason,
    required this.fadingTopics,
    required this.smallestRecoveryMinutes,
    required this.relatedAssessmentIds,
    required this.nextReviewLabel,
    required this.inspectableSteps,
  });

  final MemoryWeatherState state;
  final String headline;
  final String reason;
  final List<ReviewTopic> fadingTopics;
  final int smallestRecoveryMinutes;
  final List<String> relatedAssessmentIds;
  final String nextReviewLabel;
  final List<String> inspectableSteps;
}

/// Heuristic memory weather — not an exact forecast.
class MemoryWeatherEngine {
  const MemoryWeatherEngine();

  MemoryWeatherInsight evaluate({
    required List<ReviewTopic> topics,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final steps = <String>[
      'Looked at last review times, confidence, and stability where available.',
      'This is a directional signal, not a precise prediction.',
    ];

    final fading = <ReviewTopic>[];
    var overdueCount = 0;
    var lowConf = 0;
    var recovering = 0;

    for (final t in topics) {
      final next = t.nextReviewAt;
      final last = t.lastReviewedAt;
      final conf = t.confidence;

      if (next != null && next.isBefore(at)) {
        overdueCount++;
        fading.add(t);
        steps.add('“${t.title}” review window has passed.');
      } else if (conf != null && conf < 0.4) {
        lowConf++;
        fading.add(t);
        steps.add('“${t.title}” confidence is low (${(conf * 100).round()}%).');
      } else if (last != null &&
          at.difference(last).inDays >= 7 &&
          (t.stabilityDays == null || t.stabilityDays! < 5)) {
        fading.add(t);
        steps.add('“${t.title}” has gone a week without review.');
      }

      if (last != null && at.difference(last).inHours < 36 && conf != null && conf < 0.55) {
        recovering++;
      }
    }

    MemoryWeatherState state;
    if (topics.isEmpty) {
      state = MemoryWeatherState.clear;
      steps.add('No review topics yet — weather stays clear by default.');
    } else if (recovering > 0 && overdueCount == 0) {
      state = MemoryWeatherState.recoveryUnderway;
    } else if (overdueCount >= 3 || (lowConf + overdueCount) >= 4) {
      state = MemoryWeatherState.fog;
    } else if (fading.isNotEmpty) {
      state = MemoryWeatherState.clouding;
    } else {
      state = MemoryWeatherState.clear;
    }

    final related = <String>{};
    for (final t in fading) {
      related.addAll(t.assessmentIds);
    }

    final recoveryMins = fading.isEmpty
        ? 8
        : (modeMinutesFor(fading.first)).clamp(6, 18);

    final nextLabel = fading.isEmpty
        ? 'Nothing urgent — keep light spaced reviews when gaps appear.'
        : 'Next: short recall on “${fading.first.title}” (~$recoveryMins min).';

    final headline = switch (state) {
      MemoryWeatherState.clear => 'Memory looks clear',
      MemoryWeatherState.clouding => '${fading.length} concept(s) clouding',
      MemoryWeatherState.fog => 'Fog on several concepts',
      MemoryWeatherState.recoveryUnderway => 'Recovery underway',
    };

    final reason = switch (state) {
      MemoryWeatherState.clear =>
        'Recent reviews and confidence look stable enough for now.',
      MemoryWeatherState.clouding =>
        'A few topics are overdue or low-confidence — a small recall helps.',
      MemoryWeatherState.fog =>
        'Several topics need attention; start with the smallest recovery session.',
      MemoryWeatherState.recoveryUnderway =>
        'You recently practised weak items — keep the streak gentle, not punitive.',
    };

    return MemoryWeatherInsight(
      state: state,
      headline: headline,
      reason: reason,
      fadingTopics: fading,
      smallestRecoveryMinutes: recoveryMins,
      relatedAssessmentIds: related.toList(),
      nextReviewLabel: nextLabel,
      inspectableSteps: steps,
    );
  }

  int modeMinutesFor(ReviewTopic t) {
    if (t.questions.isEmpty) return 8;
    return (t.questions.length * 3).clamp(6, 18);
  }
}
