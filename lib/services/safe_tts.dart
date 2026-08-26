import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_voice_settings.dart';

/// Windows SAPI crashes if we await speak-completion or overlap stop/speak.
class SafeTts {
  SafeTts._();
  static final instance = SafeTts._();

  final _tts = FlutterTts();
  Completer<void>? _done;
  var _bound = false;
  Future<void> _queue = Future.value();

  void _ensureHandlers() {
    if (_bound) return;
    _bound = true;
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() => _finish());
    _tts.setCancelHandler(() => _finish());
    _tts.setErrorHandler((_) => _finish());
  }

  void _finish() {
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<List<TtsVoiceChoice>> voices() {
    return _enqueue(() async {
      _ensureHandlers();
      try {
        final raw = await _tts.getVoices.timeout(const Duration(seconds: 4));
        final parsed = TtsVoiceSettings.parse(raw);
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {}
      return const [
        TtsVoiceChoice(name: 'Microsoft David Desktop', locale: 'en-US'),
        TtsVoiceChoice(name: 'Microsoft Zira Desktop', locale: 'en-US'),
        TtsVoiceChoice(name: 'Microsoft Mark', locale: 'en-US'),
      ];
    });
  }

  Future<void> stop() {
    return _enqueue(() async {
      _ensureHandlers();
      try {
        await _tts.stop();
      } catch (_) {}
      _finish();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
  }

  Future<void> speak({
    required String text,
    TtsVoiceChoice? voice,
    double rate = 0.42,
  }) {
    return _enqueue(() async {
      _ensureHandlers();
      final cleaned = _sanitize(text);
      if (cleaned.isEmpty) return;
      try {
        await _tts.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 80));
      try {
        if (voice != null &&
            voice.name.trim().isNotEmpty &&
            voice.locale.trim().isNotEmpty) {
          await _tts.setVoice(voice.asMap);
        }
      } catch (_) {}
      try {
        await _tts.setSpeechRate(rate.clamp(0.2, 0.7));
        await _tts.setVolume(1);
      } catch (_) {}

      final chunks = _chunks(cleaned);
      for (final chunk in chunks) {
        _done = Completer<void>();
        try {
          await _tts.speak(chunk);
        } catch (_) {
          _finish();
          return;
        }
        await (_done?.future ?? Future.value())
            .timeout(Duration(seconds: 8 + chunk.length ~/ 12), onTimeout: _finish);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  static String _sanitize(String raw) {
    return raw
        .replaceAll(RegExp(r'[<>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _chunks(String text) {
    if (text.length <= 280) return [text];
    final out = <String>[];
    var rest = text;
    while (rest.length > 280) {
      var cut = rest.lastIndexOf(RegExp(r'[.!?]\s'), 280);
      if (cut < 80) cut = rest.lastIndexOf(' ', 280);
      if (cut < 80) cut = 280;
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }
}
