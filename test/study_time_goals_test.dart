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

  test('All subjects goal is the sum of each subject goal', () {
    expect(combinedWeekGoalHours(const [], 10), 10);
    expect(combinedWeekGoalHours(const [null, null], 10), 20);
    expect(combinedWeekGoalHours(const [4, null, 8], 10), 22);
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
      combinedWeekGoalHours(
        [maths.weekGoalHours, piano.weekGoalHours],
        10,
      ),
      16,
    );
  });
}
