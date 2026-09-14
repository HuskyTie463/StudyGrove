import 'study_ai_exceptions.dart';

/// True for provider auth failures that another key/provider may still pass.
bool isStudyAiAuthFailure(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('incorrect api key') ||
      raw.contains('invalid api key') ||
      raw.contains('invalid x-api-key') ||
      raw.contains('authentication_error') ||
      raw.contains('could not authenticate') ||
      raw.contains('unauthorized');
}

/// Banner after quiz/flashcard generation.
///
/// A working deck (AI or local fallback) must not show a leftover provider
/// failure such as "Incorrect API key provided".
String? studyAiSessionNote({
  required bool fromAi,
  Object? error,
  required bool hasItems,
}) {
  if (fromAi) return 'Generated with Study AI.';
  if (error == null) return null;
  if (error is StudyAiAllowanceException ||
      error is StudyAiProRequiredException) {
    return '$error';
  }
  if (hasItems) return null;
  return '$error';
}
