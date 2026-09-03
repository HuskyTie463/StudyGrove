import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'neural_tts.dart';
import 'study_ai_proxy.dart';
import 'study_ai_settings.dart';

enum RealtimePhase {
  connecting,
  listening,
  userSpeaking,
  tutorSpeaking,
  error,
  stopped,
}

class RealtimeLine {
  const RealtimeLine({required this.fromTutor, required this.text});
  final bool fromTutor;
  final String text;
}

/// Live OpenAI Realtime tutor: mic PCM in, spoken audio out, interruptible.
class RealtimeTutor {
  RealtimeTutor();

  static const _models = <String>[
    'gpt-realtime-2.1',
    'gpt-realtime-2',
    'gpt-realtime',
    'gpt-realtime-mini',
  ];

  final _recorder = AudioRecorder();
  final _pcm = _LivePcmOut();

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  var _muted = false;
  var _usedSimpleSession = false;
  var _greeted = false;
  var _micReady = false;
  var _smoothedLevel = 0.0;
  var _micRate = 24000;
  DateTime _lastLevelAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _playbackGateUntil = DateTime.fromMillisecondsSinceEpoch(0);
  String _tutorBuf = '';
  String _instructions = '';
  String _voice = 'sage';
  String _model = _models.first;
  RealtimePhase phase = RealtimePhase.stopped;

  void Function(RealtimePhase phase)? onPhase;
  void Function(RealtimeLine line)? onLine;
  void Function(String message)? onError;
  void Function(double level)? onLevel;

  Future<void> start({
    required String instructions,
    String voice = 'sage',
  }) async {
    await stop();
    if (!studyAiSettings.ready) await studyAiSettings.load();
    _setPhase(RealtimePhase.connecting);
    _instructions = instructions;
    _voice = NeuralVoice.realtimeId(voice);
    _usedSimpleSession = false;
    _greeted = false;
    _micReady = false;
    try {
      await _pcm.init();
      final session = await _sessionCredentials();
      _ws = await _connect(session.key, preferModel: session.model);
      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: (Object e) {
          if (phase == RealtimePhase.stopped || phase == RealtimePhase.error) {
            return;
          }
          _fail(_friendlySocketError(e));
        },
        onDone: () {
          if (phase != RealtimePhase.stopped && phase != RealtimePhase.error) {
            _fail('The voice session closed. Tap Retry.');
          }
        },
      );
      _sendSession(includeTranscription: true);
    } catch (e) {
      _fail(_friendlySocketError(e));
    }
  }

  Future<void> stop() async {
    await _cleanup();
    phase = RealtimePhase.stopped;
    onPhase?.call(RealtimePhase.stopped);
  }

  Future<void> interrupt() => _interruptTutor();

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _ws == null) return;
    if (phase == RealtimePhase.stopped ||
        phase == RealtimePhase.error ||
        phase == RealtimePhase.connecting) {
      return;
    }
    if (phase == RealtimePhase.tutorSpeaking) {
      await _interruptTutor();
    }
    onLine?.call(RealtimeLine(fromTutor: false, text: trimmed));
    _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': trimmed},
        ],
      },
    });
    _send({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio'],
      },
    });
  }

  Future<void> _cleanup() async {
    _greeted = false;
    _tutorBuf = '';
    _micReady = false;
    _smoothedLevel = 0;
    onLevel?.call(0);
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    await _pcm.reset();
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) {
      _smoothedLevel = 0;
      onLevel?.call(0);
      await _micSub?.cancel();
      _micSub = null;
      try {
        await _recorder.stop();
      } catch (_) {}
    } else if (phase != RealtimePhase.stopped &&
        phase != RealtimePhase.error &&
        phase != RealtimePhase.connecting) {
      await _startMic();
    }
  }

  Future<({String key, String? model})> _sessionCredentials() async {
    if (studyAiSettings.usesSpeechProxy) {
      final data = await StudyAiProxy.postJson(
        '/v1/openai/realtime/sessions',
        body: {
          'model': _models.first,
          'voice': _voice,
        },
        timeout: const Duration(seconds: 30),
      );
      String? secret;
      final raw = data['client_secret'];
      if (raw is Map) {
        secret = raw['value'] as String?;
      } else if (raw is String) {
        secret = raw;
      }
      if (secret == null || secret.isEmpty) {
        throw Exception('Voice session could not be created.');
      }
      final model = data['model'] as String?;
      return (key: secret, model: model);
    }
    final key = studyAiSettings.openAiSpeechKey;
    if (key == null) {
      throw Exception(
        'Voice chat needs the Study AI server running, or a custom OpenAI key in Settings.',
      );
    }
    return (key: key, model: null);
  }

  Future<WebSocketChannel> _connect(String key, {String? preferModel}) async {
    Object? last;
    final models = <String>[
      if (preferModel != null && preferModel.trim().isNotEmpty) preferModel.trim(),
      ..._models,
    ];
    final seen = <String>{};
    for (final model in models) {
      if (!seen.add(model)) continue;
      try {
        final channel = IOWebSocketChannel.connect(
          Uri.parse('wss://api.openai.com/v1/realtime?model=$model'),
          headers: {
            'Authorization': 'Bearer $key',
            'OpenAI-Beta': 'realtime=v1',
          },
          pingInterval: const Duration(seconds: 15),
        );
        await channel.ready.timeout(const Duration(seconds: 12));
        _model = model;
        return channel;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? Exception('Could not open a realtime voice session.');
  }

  void _sendSession({required bool includeTranscription}) {
    _send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'model': _model,
        'instructions': _instructions,
        'output_modalities': ['audio'],
        'audio': {
          'input': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'turn_detection': {
              'type': 'server_vad',
              'threshold': 0.55,
              'prefix_padding_ms': 250,
              'silence_duration_ms': 700,
              'create_response': true,
              'interrupt_response': false,
            },
            if (includeTranscription)
              'transcription': {'model': 'gpt-4o-mini-transcribe'},
          },
          'output': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'voice': _voice,
          },
        },
      },
    });
  }

  RecordConfig _micConfig(int rate) => RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: rate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      );

  bool get _holdMic =>
      _muted ||
      phase == RealtimePhase.tutorSpeaking ||
      DateTime.now().isBefore(_playbackGateUntil);

  Future<void> _startMic() async {
    if (_micReady || _muted) return;
    final ok = await _recorder.hasPermission();
    if (!ok) {
      throw Exception('Microphone permission is needed for Voice chat.');
    }
    Stream<Uint8List> stream;
    try {
      _micRate = 24000;
      stream = await _recorder.startStream(_micConfig(24000));
    } catch (_) {
      _micRate = 48000;
      stream = await _recorder.startStream(_micConfig(48000));
    }
    _micReady = true;
    _micSub = stream.listen((chunk) {
      if (_holdMic || chunk.isEmpty || _ws == null) return;
      if (phase == RealtimePhase.connecting ||
          phase == RealtimePhase.stopped ||
          phase == RealtimePhase.error) {
        return;
      }
      var pcm = chunk;
      if (pcm.length.isOdd) {
        pcm = pcm.sublist(0, pcm.length - 1);
      }
      if (_micRate != 24000) {
        pcm = _downsampleTo24k(pcm, _micRate);
      }
      if (pcm.isEmpty) return;
      _reportLevel(_pcmRms(pcm));
      _send({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(pcm),
      });
    });
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> event;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      event = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final type = (event['type'] as String?) ?? '';
    switch (type) {
      case 'session.created':
        _sendSession(includeTranscription: true);
      case 'session.updated':
        if (phase == RealtimePhase.connecting) {
          _setPhase(RealtimePhase.listening);
          unawaited(_armMicAndGreet());
        }
      case 'error':
        _onSessionError(event);
      case 'input_audio_buffer.speech_started':
        if (_holdMic) {
          _send({'type': 'input_audio_buffer.clear'});
          break;
        }
        unawaited(_interruptTutor());
        _setPhase(RealtimePhase.userSpeaking);
      case 'input_audio_buffer.speech_stopped':
        if (phase == RealtimePhase.userSpeaking) {
          _setPhase(RealtimePhase.listening);
        }
      case 'conversation.item.input_audio_transcription.completed':
        final said = (event['transcript'] as String?)?.trim() ?? '';
        if (said.isNotEmpty) {
          onLine?.call(RealtimeLine(fromTutor: false, text: said));
        }
      case 'response.output_audio.delta':
      case 'response.audio.delta':
        if (phase != RealtimePhase.tutorSpeaking) {
          _send({'type': 'input_audio_buffer.clear'});
        }
        _setPhase(RealtimePhase.tutorSpeaking);
        final b64 = (event['delta'] as String?) ?? '';
        if (b64.isNotEmpty) {
          final pcm = base64Decode(b64);
          _reportLevel(_pcmRms(pcm));
          unawaited(_pcm.push(pcm));
        }
      case 'response.output_audio_transcript.delta':
      case 'response.audio_transcript.delta':
        _tutorBuf += (event['delta'] as String?) ?? '';
      case 'response.output_audio_transcript.done':
      case 'response.audio_transcript.done':
        final full = ((event['transcript'] as String?) ?? _tutorBuf).trim();
        _tutorBuf = '';
        if (full.isNotEmpty) {
          onLine?.call(RealtimeLine(fromTutor: true, text: full));
        }
      case 'response.output_audio.done':
      case 'response.audio.done':
        unawaited(_pcm.finishUtterance());
      case 'response.done':
      case 'response.cancelled':
        _playbackGateUntil =
            DateTime.now().add(const Duration(milliseconds: 500));
        if (phase == RealtimePhase.tutorSpeaking) {
          _setPhase(RealtimePhase.listening);
        }
      default:
        break;
    }
  }

  Future<void> _armMicAndGreet() async {
    try {
      await _startMic();
    } catch (e) {
      _fail('$e');
      return;
    }
    _greetOnce();
  }

  void _onSessionError(Map<String, dynamic> event) {
    final err = event['error'];
    var message = 'Voice session error.';
    var code = '';
    if (err is Map) {
      if (err['message'] is String) message = err['message'] as String;
      if (err['code'] is String) code = err['code'] as String;
    }
    final lower = message.toLowerCase();
    if (_isIgnorableError(code, lower)) return;
    if (phase == RealtimePhase.connecting && !_usedSimpleSession) {
      _usedSimpleSession = true;
      _sendSession(includeTranscription: false);
      return;
    }
    _fail(message);
  }

  bool _isIgnorableError(String code, String lower) {
    if (code == 'response_cancel_not_active') return true;
    if (lower.contains('no active response')) return true;
    if (lower.contains('cancellation failed')) return true;
    if (lower.contains('buffer is empty')) return true;
    return false;
  }

  void _greetOnce() {
    if (_greeted) return;
    _greeted = true;
    _send({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio'],
        'instructions':
            'Greet the student in one short spoken sentence, then ask what they want to work on from the notes.',
      },
    });
  }

  Future<void> _interruptTutor() async {
    if (phase == RealtimePhase.tutorSpeaking) {
      _send({'type': 'response.cancel'});
      _send({'type': 'output_audio_buffer.clear'});
    }
    await _pcm.reset();
    _tutorBuf = '';
  }

  void _send(Map<String, dynamic> event) {
    try {
      _ws?.sink.add(jsonEncode(event));
    } catch (_) {}
  }

  void _setPhase(RealtimePhase next) {
    if (phase == RealtimePhase.stopped && next != RealtimePhase.connecting) {
      return;
    }
    if (phase == RealtimePhase.error && next != RealtimePhase.connecting) {
      return;
    }
    phase = next;
    onPhase?.call(next);
  }

  void _fail(String message) {
    if (phase == RealtimePhase.error || phase == RealtimePhase.stopped) return;
    phase = RealtimePhase.error;
    onError?.call(message);
    onPhase?.call(RealtimePhase.error);
    unawaited(_cleanup());
  }

  void _reportLevel(double rms) {
    final now = DateTime.now();
    if (now.difference(_lastLevelAt).inMilliseconds < 32) return;
    _lastLevelAt = now;
    _smoothedLevel = _smoothedLevel * 0.52 + rms * 0.48;
    onLevel?.call((_smoothedLevel * 5.2).clamp(0.0, 1.0));
  }

  static String _friendlySocketError(Object e) {
    final text = '$e';
    if (text.toLowerCase().contains('failed') ||
        text.toLowerCase().contains('closed')) {
      return 'Connection dropped. Tap Retry.';
    }
    return text;
  }

  static Uint8List _downsampleTo24k(Uint8List pcm, int fromRate) {
    final inSamples = pcm.length ~/ 2;
    if (inSamples < 2 || fromRate <= 24000) return pcm;
    final outSamples = (inSamples * 24000) ~/ fromRate;
    final out = Uint8List(outSamples * 2);
    for (var i = 0; i < outSamples; i++) {
      final src = ((i * fromRate) ~/ 24000).clamp(0, inSamples - 1);
      out[i * 2] = pcm[src * 2];
      out[i * 2 + 1] = pcm[src * 2 + 1];
    }
    return out;
  }

  static double _pcmRms(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    if (n == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final lo = pcm[i * 2];
      final hi = pcm[i * 2 + 1];
      var sample = lo | (hi << 8);
      if (sample >= 32768) sample -= 65536;
      sum += sample * sample;
    }
    return math.sqrt(sum / n) / 32768.0;
  }
}

class _LivePcmOut {
  AudioSource? _source;
  SoundHandle? _handle;
  var _ready = false;
  var _utteranceDone = false;

  Future<void> init() async {
    if (SoLoud.instance.isInitialized) {
      _ready = true;
      return;
    }
    await SoLoud.instance.init(
      sampleRate: 24000,
      channels: Channels.mono,
      bufferSize: 2048,
      automaticCleanup: true,
    );
    _ready = true;
  }

  Future<void> push(Uint8List pcm) async {
    if (!_ready || pcm.isEmpty) return;
    final handle = _handle;
    final needNew = _utteranceDone ||
        _source == null ||
        handle == null ||
        !SoLoud.instance.getIsValidVoiceHandle(handle);
    if (needNew) {
      await reset();
      _source = SoLoud.instance.setBufferStream(
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.12,
        sampleRate: 24000,
        channels: Channels.mono,
        format: BufferType.s16le,
        autoDispose: false,
        maxBufferSizeDuration: const Duration(minutes: 8),
      );
      _handle = SoLoud.instance.play(_source!);
    }
    SoLoud.instance.addAudioDataStream(_source!, pcm);
  }

  Future<void> finishUtterance() async {
    final source = _source;
    if (source == null) return;
    try {
      SoLoud.instance.setDataIsEnded(source);
    } catch (_) {}
    _utteranceDone = true;
  }

  Future<void> reset() async {
    final handle = _handle;
    if (handle != null) {
      try {
        SoLoud.instance.stop(handle);
      } catch (_) {}
    }
    final source = _source;
    if (source != null) {
      try {
        SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
    _handle = null;
    _source = null;
    _utteranceDone = false;
  }
}
