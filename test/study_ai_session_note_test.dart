import 'package:flutter_organiser/services/study_ai_exceptions.dart';
import 'package:flutter_organiser/services/study_ai_session_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success clears any provider failure', () {
    expect(
      studyAiSessionNote(
        fromAi: true,
        error: Exception('Incorrect API key provided'),
        hasItems: true,
      ),
      'Generated with Study AI.',
    );
  });

  test('working fallback swallows incorrect API key', () {
    expect(
      studyAiSessionNote(
        fromAi: false,
        error: Exception('Incorrect API key provided'),
        hasItems: true,
      ),
      isNull,
    );
  });

  test('shows the error only when nothing was generated', () {
    expect(
      studyAiSessionNote(
        fromAi: false,
        error: Exception('Incorrect API key provided'),
        hasItems: false,
      ),
      'Exception: Incorrect API key provided',
    );
  });

  test('allowance still surfaces even if local items exist', () {
    final error = StudyAiAllowanceException(resetsOn: DateTime(2026, 10, 1));
    expect(
      studyAiSessionNote(fromAi: false, error: error, hasItems: true),
      '$error',
    );
  });

  test('detects OpenAI-style auth failures for provider retry', () {
    expect(
      isStudyAiAuthFailure(Exception('Incorrect API key provided')),
      isTrue,
    );
    expect(isStudyAiAuthFailure(Exception('Rate limited')), isFalse);
  });
}
