import '../models/models.dart';

class CalendarGap {
  const CalendarGap({
    required this.startMinutes,
    required this.endMinutes,
    required this.usableMinutes,
    required this.travelBufferMinutes,
    required this.nextCommitmentTitle,
    required this.reason,
  });

  final int startMinutes;
  final int endMinutes;
  final int usableMinutes;
  final int travelBufferMinutes;
  final String? nextCommitmentTitle;
  final String reason;
}

class PreparedSession {
  const PreparedSession({
    required this.gap,
    required this.title,
    required this.durationMinutes,
    required this.mode,
    required this.materialLabel,
    required this.whySelected,
    required this.endsBeforeCommitment,
    this.assessmentId,
    this.topicId,
  });

  final CalendarGap gap;
  final String title;
  final int durationMinutes;
  final StudyContextMode mode;
  final String materialLabel;
  final String whySelected;
  final bool endsBeforeCommitment;
  final String? assessmentId;
  final String? topicId;
}

/// Detects usable gaps between commitments and proposes one finishable session.
class CalendarGapEngine {
  const CalendarGapEngine({
    this.defaultTravelBufferMinutes = 10,
    this.minUsableMinutes = 8,
    this.maxSessionMinutes = 45,
  });

  final int defaultTravelBufferMinutes;
  final int minUsableMinutes;
  final int maxSessionMinutes;

  List<CalendarGap> detectGaps({
    required List<AppEvent> events,
    required int dayStartMinutes,
    required int dayEndMinutes,
    int? travelBufferMinutes,
    FrictionReason? recentFriction,
  }) {
    final buffer = travelBufferMinutes ??
        (recentFriction == FrictionReason.travel
            ? defaultTravelBufferMinutes + 5
            : defaultTravelBufferMinutes);

    final sorted = [...events]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final gaps = <CalendarGap>[];
    var cursor = dayStartMinutes;

    for (final e in sorted) {
      final gapEnd = e.startMinutes - buffer;
      if (gapEnd - cursor >= minUsableMinutes) {
        gaps.add(CalendarGap(
          startMinutes: cursor,
          endMinutes: gapEnd,
          usableMinutes: gapEnd - cursor,
          travelBufferMinutes: buffer,
          nextCommitmentTitle: e.title,
          reason:
              'Open until ${e.title}; $buffer min travel/transition protected.',
        ));
      }
      cursor = e.endMinutes > cursor ? e.endMinutes : cursor;
    }

    if (dayEndMinutes - cursor >= minUsableMinutes) {
      gaps.add(CalendarGap(
        startMinutes: cursor,
        endMinutes: dayEndMinutes,
        usableMinutes: dayEndMinutes - cursor,
        travelBufferMinutes: 0,
        nextCommitmentTitle: null,
        reason: 'Open window until end of study day.',
      ));
    }

    return gaps;
  }

  PreparedSession? recommendSession({
    required List<CalendarGap> gaps,
    required List<Assessment> assessments,
    required List<ReviewTopic> topics,
    StudyContextMode mode = StudyContextMode.balanced,
    FrictionReason? recentFriction,
  }) {
    if (gaps.isEmpty) return null;

    // Prefer the soonest usable gap that can fit a finishable session.
    final gap = gaps.first;
    var duration = gap.usableMinutes.clamp(minUsableMinutes, maxSessionMinutes);

    if (mode == StudyContextMode.lowEnergy ||
        recentFriction == FrictionReason.tooTired) {
      duration = duration.clamp(minUsableMinutes, 15);
    } else if (mode == StudyContextMode.walking ||
        recentFriction == FrictionReason.wrongEnvironment) {
      duration = duration.clamp(minUsableMinutes, 20);
    } else if (recentFriction == FrictionReason.tooLong) {
      duration = duration.clamp(minUsableMinutes, 12);
    }

    final active = assessments.where((a) => a.isActive).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    ReviewTopic? fading;
    for (final t in topics) {
      if (t.nextReviewAt != null &&
          t.nextReviewAt!.isBefore(DateTime.now().add(const Duration(days: 1)))) {
        fading = t;
        break;
      }
      if (t.confidence != null && t.confidence! < 0.45) {
        fading = t;
        break;
      }
    }

    if (fading != null &&
        mode != StudyContextMode.walking &&
        recentFriction != FrictionReason.tooDifficult) {
      return PreparedSession(
        gap: gap,
        title: 'Recall: ${fading.title}',
        durationMinutes: duration,
        mode: mode,
        materialLabel: fading.title,
        whySelected:
            'Concept may be fading (review timing/confidence). Fits $duration min and ends before the next commitment.',
        endsBeforeCommitment: true,
        topicId: fading.id,
        assessmentId:
            fading.assessmentIds.isEmpty ? null : fading.assessmentIds.first,
      );
    }

    if (active.isNotEmpty) {
      final a = active.first;
      final open = a.subtasks.where((s) => !s.done).toList();
      final label = open.isNotEmpty ? open.first.title : a.title;
      // Avoid unfinishable deep tasks in short gaps.
      final tooAmbitious = open.isNotEmpty &&
          duration < 15 &&
          (a.estimatedPrepMinutes ?? 60) > 40;
      if (tooAmbitious && fading == null) {
        return PreparedSession(
          gap: gap,
          title: 'Micro-prep: $label',
          durationMinutes: duration.clamp(minUsableMinutes, 12),
          mode: mode,
          materialLabel: label,
          whySelected:
              'Gap is short; chose a micro slice of upcoming work rather than an unfinishable block.',
          endsBeforeCommitment: true,
          assessmentId: a.id,
        );
      }
      return PreparedSession(
        gap: gap,
        title: label,
        durationMinutes: duration,
        mode: mode,
        materialLabel: '${a.course}: ${a.title}',
        whySelected:
            'Nearest due assessment with open prep. Session ends before ${gap.nextCommitmentTitle ?? 'day end'}; ${gap.travelBufferMinutes} min buffer kept.',
        endsBeforeCommitment: true,
        assessmentId: a.id,
      );
    }

    return PreparedSession(
      gap: gap,
      title: 'Light review',
      durationMinutes: duration,
      mode: mode,
      materialLabel: 'General review',
      whySelected:
          'No linked assessments/topics yet — a short protected review still recovers the gap.',
      endsBeforeCommitment: true,
    );
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
