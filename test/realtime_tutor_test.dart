import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_organiser/services/realtime_tutor.dart';

void main() {
  test('realtime headers authenticate without the disabled beta handshake', () {
    final headers = RealtimeTutor.realtimeHeaders('sk-test');
    expect(headers['Authorization'], 'Bearer sk-test');
    expect(headers.containsKey('OpenAI-Beta'), isFalse);
    expect(
      headers.values.any((v) => v.toLowerCase().contains('realtime=v1')),
      isFalse,
    );
  });

  test('explainDisconnect maps the beta close that looked like a retry loop', () {
    expect(
      RealtimeTutor.explainDisconnect(
        code: 4000,
        reason: 'invalid_request_error.beta_api_shape_disabled',
      ),
      contains('outdated realtime handshake'),
    );
    expect(
      RealtimeTutor.explainDisconnect(
        error: 'The voice session closed. Tap Retry.',
      ),
      'The voice session closed.',
    );
    expect(
      RealtimeTutor.explainDisconnect(
        error: Exception('invalid_api_key'),
      ),
      contains('authenticate'),
    );
  });

  test('websocket interrupt does not send WebRTC-only output_audio_buffer.clear', () {
    final types = RealtimeTutor.websocketInterruptEvents
        .map((e) => e['type'])
        .toList();
    expect(types, contains('response.cancel'));
    expect(types, contains('input_audio_buffer.clear'));
    expect(types, isNot(contains('output_audio_buffer.clear')));
  });

  test('output_audio_buffer invalid_value is ignorable on WebSocket', () {
    expect(
      RealtimeTutor.isIgnorableSessionError(
        'invalid_value',
        'Invalid value: output_audio_buffer.clear is only supported for WebRTC',
      ),
      isTrue,
    );
    expect(
      RealtimeTutor.isIgnorableSessionError('unknown', 'something else'),
      isFalse,
    );
  });

  test('ignoreUserInput blocks speaker echo during playback and cooldown', () {
    final now = DateTime(2026, 1, 1, 12);
    expect(
      RealtimeTutor.ignoreUserInput(
        echoLocked: true,
        muted: false,
        tutorSpeaking: false,
        now: now,
        gateUntil: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      isTrue,
    );
    expect(
      RealtimeTutor.ignoreUserInput(
        echoLocked: false,
        muted: false,
        tutorSpeaking: true,
        now: now,
        gateUntil: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      isTrue,
    );
    expect(
      RealtimeTutor.ignoreUserInput(
        echoLocked: false,
        muted: false,
        tutorSpeaking: false,
        now: now,
        gateUntil: now.add(const Duration(milliseconds: 400)),
      ),
      isTrue,
    );
    expect(
      RealtimeTutor.ignoreUserInput(
        echoLocked: false,
        muted: false,
        tutorSpeaking: false,
        now: now,
        gateUntil: now.subtract(const Duration(milliseconds: 1)),
      ),
      isFalse,
    );
  });
}
