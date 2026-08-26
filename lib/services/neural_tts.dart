import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'consolidation_engine.dart';
import 'study_ai_settings.dart';

class NeuralTtsException implements Exception {
  NeuralTtsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NeuralVoice {
  const NeuralVoice({
    required this.id,
    required this.label,
    required this.hint,
  });

  final String id;
  final String label;
  final String hint;

  static const nova = NeuralVoice(
    id: 'nova',
    label: 'Nova',
    hint: 'Bright and clear — a strong default for lectures',
  );
  static const sage = NeuralVoice(
    id: 'sage',
    label: 'Sage',
    hint: 'Calm, even, good for long recaps',
  );
  static const coral = NeuralVoice(
    id: 'coral',
    label: 'Coral',
    hint: 'Soft and friendly',
  );
  static const shimmer = NeuralVoice(
    id: 'shimmer',
    label: 'Shimmer',
    hint: 'Light and easy to follow',
  );
  static const alloy = NeuralVoice(
    id: 'alloy',
    label: 'Alloy',
    hint: 'Neutral and steady',
  );
  static const ash = NeuralVoice(
    id: 'ash',
    label: 'Ash',
    hint: 'Low-key and even',
  );
  static const echo = NeuralVoice(
    id: 'echo',
    label: 'Echo',
    hint: 'Measured, slightly formal',
  );
  static const fable = NeuralVoice(
    id: 'fable',
    label: 'Fable',
    hint: 'A little more story-like',
  );
  static const onyx = NeuralVoice(
    id: 'onyx',
    label: 'Onyx',
    hint: 'Deeper register',
  );
  static const ballad = NeuralVoice(
    id: 'ballad',
    label: 'Ballad',
    hint: 'Warm narrative',
  );

  static const all = <NeuralVoice>[
    nova,
    sage,
    coral,
    shimmer,
    alloy,
    ash,
    echo,
    fable,
    onyx,
    ballad,
  ];

  static NeuralVoice byId(String? id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return nova;
  }

  /// OpenAI Realtime only accepts this set. TTS names like nova/fable/onyx map across.
  static const realtimeIds = <String>{
    'alloy',
    'ash',
    'ballad',
    'coral',
    'echo',
    'sage',
    'shimmer',
    'verse',
    'marin',
    'cedar',
  };

  static String realtimeId(String? id) {
    final raw = (id ?? '').trim().toLowerCase();
    if (realtimeIds.contains(raw)) return raw;
    return switch (raw) {
      'nova' => 'marin',
      'fable' => 'ballad',
      'onyx' => 'verse',
      _ => 'sage',
    };
  }
}

/// OpenAI neural speech for Listen. Binary MP3 in, device playback out.
class NeuralTts {
  NeuralTts._();
  static final instance = NeuralTts._();

  final _player = AudioPlayer();
  var _stop = false;
  Completer<void>? _playDone;

  Future<void> stop() async {
    _stop = true;
    _finishPlay();
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> playSample(NeuralVoice voice) {
    return speak(
      text:
          'This is how I sound when reading your lecture notes. Slow enough to follow, clear enough to keep.',
      voice: voice,
      vibe: ListenVibe.calmCoach,
      cacheKey: 'sample-${voice.id}',
    );
  }

  Future<void> speak({
    required String text,
    required NeuralVoice voice,
    required ListenVibe vibe,
    String? cacheKey,
    void Function()? onStarted,
  }) async {
    final key = studyAiSettings.openAiSpeechKey;
    if (key == null) {
      throw NeuralTtsException(
        'Natural Listen voices need an OpenAI key. Add one in Settings.',
      );
    }
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return;

    await stop();
    _stop = false;

    final chunks = cacheKey != null ? [cleaned] : _chunks(cleaned);
    Future<File>? upcoming;

    for (var i = 0; i < chunks.length; i++) {
      if (_stop) return;
      final file = upcoming != null
          ? await upcoming
          : await _synthesize(
              key: key,
              text: chunks[i],
              voice: voice,
              vibe: vibe,
              cacheKey: cacheKey,
            );
      if (_stop) return;
      if (i + 1 < chunks.length) {
        upcoming = _synthesize(
          key: key,
          text: chunks[i + 1],
          voice: voice,
          vibe: vibe,
        );
      } else {
        upcoming = null;
      }
      onStarted?.call();
      onStarted = null;
      await _playFile(file);
    }
  }

  Future<void> _playFile(File file) async {
    _playDone = Completer<void>();
    StreamSubscription<void>? sub;
    sub = _player.onPlayerComplete.listen((_) => _finishPlay());
    try {
      await _player.play(DeviceFileSource(file.path));
      await (_playDone?.future ?? Future.value()).timeout(
        const Duration(minutes: 4),
        onTimeout: _finishPlay,
      );
    } finally {
      await sub.cancel();
    }
  }

  void _finishPlay() {
    final c = _playDone;
    _playDone = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<File> _synthesize({
    required String key,
    required String text,
    required NeuralVoice voice,
    required ListenVibe vibe,
    String? cacheKey,
  }) async {
    if (cacheKey != null) {
      final cached = _cacheFile(cacheKey);
      if (await cached.exists() && await cached.length() > 800) return cached;
    }
    try {
      return await _request(
        key: key,
        text: text,
        voice: voice,
        model: 'gpt-4o-mini-tts',
        instructions: _instructions(vibe),
        cacheKey: cacheKey,
      );
    } on NeuralTtsException catch (e) {
      if (!_shouldFallback(e.message)) rethrow;
      return _request(
        key: key,
        text: text,
        voice: voice,
        model: 'tts-1-hd',
        voiceId: _hdVoice(voice),
        speed: _speed(vibe),
        cacheKey: cacheKey,
      );
    }
  }

  Future<File> _request({
    required String key,
    required String text,
    required NeuralVoice voice,
    required String model,
    String? voiceId,
    String? instructions,
    double? speed,
    String? cacheKey,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'voice': voiceId ?? voice.id,
      'input': text,
      'response_format': 'mp3',
    };
    if (instructions != null && instructions.isNotEmpty) {
      body['instructions'] = instructions;
    }
    if (speed != null) body['speed'] = speed;

    final res = await http
        .post(
          Uri.parse('https://api.openai.com/v1/audio/speech'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NeuralTtsException(_errorFrom(res));
    }
    if (res.bodyBytes.length < 400) {
      throw NeuralTtsException('OpenAI returned empty audio.');
    }
    final file = cacheKey != null
        ? _cacheFile(cacheKey)
        : File(
            '${Directory.systemTemp.path}/sg_listen_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  String _hdVoice(NeuralVoice voice) {
    const hd = {'alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'};
    if (hd.contains(voice.id)) return voice.id;
    return 'nova';
  }

  bool _shouldFallback(String message) {
    final m = message.toLowerCase();
    return m.contains('model') ||
        m.contains('404') ||
        m.contains('instructions') ||
        m.contains('invalid voice') ||
        m.contains('unknown voice');
  }

  String _errorFrom(http.Response res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
      }
    } catch (_) {}
    if (res.statusCode == 401) {
      return 'OpenAI key rejected. Check the Listen key in Settings.';
    }
    if (res.statusCode == 429) return 'Rate limited. Try again in a moment.';
    return 'OpenAI speech error (${res.statusCode}).';
  }

  File _cacheFile(String cacheKey) {
    final safe = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${Directory.systemTemp.path}/sg_voice_$safe.mp3');
  }

  String _instructions(ListenVibe vibe) {
    final base =
        'You are reading a student\'s lecture recap. Enunciate. '
        'Do not sound like a robot or a commercial. Natural pace.';
    final extra = switch (vibe) {
      ListenVibe.calmCoach =>
        'Slow, grounded tutor. Warm. Pause briefly between ideas.',
      ListenVibe.gardenWalk =>
        'Unhurried, like a quiet walk. Soft, even, no theatrics.',
      ListenVibe.examDrill =>
        'Crisp and clear. Short sentences. Leave a small pause after a cue.',
      ListenVibe.storytime =>
        'Gentle narrative, as if reading a well-written lecture story.',
      ListenVibe.radioHost =>
        'Warm conversational radio host. Natural, not salesy.',
    };
    return '$base $extra';
  }

  double _speed(ListenVibe vibe) {
    return switch (vibe) {
      ListenVibe.calmCoach => 0.95,
      ListenVibe.gardenWalk => 0.9,
      ListenVibe.examDrill => 1.05,
      ListenVibe.storytime => 0.95,
      ListenVibe.radioHost => 1.0,
    };
  }

  List<String> _chunks(String text) {
    const max = 3500;
    if (text.length <= max) return [text];
    final out = <String>[];
    var rest = text;
    while (rest.length > max) {
      var cut = rest.lastIndexOf(RegExp(r'[.!?]\s'), max);
      if (cut < max ~/ 3) cut = rest.lastIndexOf(' ', max);
      if (cut < max ~/ 3) cut = max;
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }
}
