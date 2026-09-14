import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/services/study_time_service.dart';

void main() {

  test('existing subjects default to study', () {
    expect(SubjectKind.fromStorage(null), SubjectKind.study);
    expect(SubjectKind.fromStorage('study'), SubjectKind.study);
    expect(SubjectKind.fromStorage('hobby'), SubjectKind.hobby);
    expect(SubjectKind.fromStorage('nope').isHobby, isFalse);
  });

  test('a subject uses its own weekly hours, otherwise the shared default', () {
    expect(resolveWeekGoalHours(null, 10), 10);
    expect(resolveWeekGoalHours(6, 10), 6);
    expect(resolveWeekGoalHours(0, 10), 1);
    expect(resolveWeekGoalHours(99, 10), 40);
  });

  test('stored minutes win over hours, then the shared default', () {
    expect(
      resolveWeekGoalMinutes(
        subjectHours: 6,
        fallbackHours: 10,
      ),
      360,
    );
    expect(
      resolveWeekGoalMinutes(
        subjectMinutes: 150,
        subjectHours: 6,
        fallbackHours: 10,
      ),
      150,
    );
    expect(
      resolveWeekGoalMinutes(fallbackHours: 10),
      600,
    );
  });

  test('weekly goal hours and minutes become minutes to store', () {
    expect(parseWeekGoalMinutes(hours: 0, minutes: 0), isNull);
    expect(parseWeekGoalMinutes(hours: -1, minutes: 10), isNull);
    expect(parseWeekGoalMinutes(hours: 0, minutes: 25), 25);
    expect(parseWeekGoalMinutes(hours: 4, minutes: 30), 270);
    expect(parseWeekGoalMinutes(hours: 2, minutes: 0), 120);
    expect(parseWeekGoalMinutes(hours: 41, minutes: 0), 40 * 60);
  });

  test('All subjects goal is the sum of each subject goal', () {
    expect(combinedWeekGoalHours(const [], 10), 10);
    expect(combinedWeekGoalHours(const [null, null], 10), 20);
    expect(combinedWeekGoalHours(const [4, null, 8], 10), 22);
  });

  test('elapsed clock stays mm:ss then grows to h:mm:ss', () {
    expect(formatElapsedClock(Duration.zero), '00:00');
    expect(formatElapsedClock(const Duration(seconds: 9)), '00:09');
    expect(formatElapsedClock(const Duration(minutes: 3, seconds: 5)), '03:05');
    expect(
      formatElapsedClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('assessment spent label and subject minutes match Time rounding', () {
    expect(formatAssessmentSpentLabel(0), 'No time on this assessment yet');
    expect(formatAssessmentSpentLabel(45), '45s on this assessment');
    expect(formatAssessmentSpentLabel(3 * 3600 + 12 * 60), '3h 12m on this assessment');
    expect(subjectMinutesFromSession(29), 0);
    expect(subjectMinutesFromSession(30), 1);
    expect(subjectMinutesFromSession(90), 2);
  });

  test('manual hours and minutes become minutes to log', () {
    expect(parseManualStudyMinutes(hours: 0, minutes: 0), isNull);
    expect(parseManualStudyMinutes(hours: -1, minutes: 10), isNull);
    expect(parseManualStudyMinutes(hours: 0, minutes: 25), 25);
    expect(parseManualStudyMinutes(hours: 1, minutes: 30), 90);
    expect(parseManualStudyMinutes(hours: 2, minutes: 0), 120);
    expect(parseManualStudyMinutes(hours: 25, minutes: 0), 24 * 60);
  });

  test('removing time never goes below zero and asks before an hour', () {
    expect(clampRemovedStudyMinutes(0, 20), 0);
    expect(clampRemovedStudyMinutes(40, 0), 0);
    expect(clampRemovedStudyMinutes(40, 15), 15);
    expect(clampRemovedStudyMinutes(40, 90), 40);
    expect(remainingStudyMinutes(40, 15), 25);
    expect(remainingStudyMinutes(40, 90), 0);
    expect(shouldConfirmStudyTimeRemoval(59), isFalse);
    expect(shouldConfirmStudyTimeRemoval(60), isTrue);
    final today = DateTime(2026, 9, 14);
    expect(formatLoggedStudyDay('2026-09-14', now: today), 'Today');
    expect(formatLoggedStudyDay('2026-09-13', now: today), 'Yesterday');
    expect(formatLoggedStudyDay('2026-09-11', now: today), 'Fri 11/9');
  });

  test('Subject stores kind and weekly hours for Time to read', () {
    final maths = Subject(
      id: 'm',
      name: 'Maths',
      colorValue: 0xFF6FA98A,
      weekGoalHours: 6,
    );
    final piano = Subject(
      id: 'p',
      name: 'Piano',
      colorValue: 0xFFE8B4A0,
      kind: SubjectKind.hobby,
    );
    expect(maths.isHobby, isFalse);
    expect(piano.isHobby, isTrue);
    expect(resolveWeekGoalHours(maths.weekGoalHours, 10), 6);
    expect(resolveWeekGoalHours(piano.weekGoalHours, 10), 10);
    expect(
      resolveWeekGoalMinutes(
        subjectMinutes: 90,
        subjectHours: piano.weekGoalHours,
        fallbackHours: 10,
      ),
      90,
    );
    expect(
      combinedWeekGoalHours(
        [maths.weekGoalHours, piano.weekGoalHours],
        10,
      ),
      16,
    );
  });

  test('goal ratio stays under 1 until overtime, then exceeds 1', () {
    expect(studyGoalRatio(0, 600), 0);
    expect(studyGoalRatio(300, 600), 0.5);
    expect(studyGoalRatio(600, 600), 1);
    expect(studyGoalRatio(780, 600), closeTo(1.3, 0.0001));
    expect(studyGoalRatio(30, 0), 0);
  });

  test('overtime rings stack extra darker laps instead of capping at 100%', () {
    expect(studyRingLapSweeps(0), isEmpty);
    expect(studyRingLapSweeps(0.4), [0.4]);
    expect(studyRingLapSweeps(1), [1.0]);
    final overtime = studyRingLapSweeps(1.3);
    expect(overtime.length, 2);
    expect(overtime[0], 1.0);
    expect(overtime[1], closeTo(0.3, 0.0001));
    expect(studyRingLapSweeps(2), [1.0, 1.0]);
    final third = studyRingLapSweeps(2.4);
    expect(third.length, 3);
    expect(third[0], 1.0);
    expect(third[1], 1.0);
    expect(third[2], closeTo(0.4, 0.0001));
    expect(studyRingLapSweeps(5, maxLaps: 4), [1.0, 1.0, 1.0, 1.0]);
  });

  test('Time graph Y axis converts minutes to hour ticks', () {
    expect(studyMinutesToHours(0), 0);
    expect(studyMinutesToHours(30), 0.5);
    expect(studyMinutesToHours(90), 1.5);
    expect(studyTimeChartMaxHours(0), 1);
    expect(studyTimeChartMaxHours(0.4), 1);
    expect(studyTimeChartMaxHours(1.5), 2);
    expect(studyTimeChartMaxHours(3.2), 4);
    expect(studyTimeChartHourInterval(1), 0.5);
    expect(studyTimeChartHourInterval(4), 1);
    expect(formatStudyChartHours(0), '0');
    expect(formatStudyChartHours(1), '1h');
    expect(formatStudyChartHours(2), '2h');
    expect(formatStudyChartHours(0.5), '0.5h');
    expect(formatStudyChartHours(0.25), '0.25h');
  });

  test('extra laps stay the same hue and get darker, not red', () {
    const sage = Color(0xFF6FA98A);
    final first = studyRingLapColor(sage, 0);
    final second = studyRingLapColor(sage, 1);
    final third = studyRingLapColor(sage, 2);
    expect(first, sage);
    expect(second.r, lessThan(sage.r));
    expect(second.g, lessThan(sage.g));
    expect(second.b, lessThan(sage.b));
    expect(third.r, lessThan(second.r));
    expect(third.g, lessThan(second.g));
    expect(second.g, greaterThan(second.r));
    expect(second.g, greaterThan(second.b));
  });
}
