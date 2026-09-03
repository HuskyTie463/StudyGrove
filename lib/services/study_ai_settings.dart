import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyAiProvider { openai, anthropic }

extension StudyAiProviderX on StudyAiProvider {
  String get id => name;

  String get label => switch (this) {
        StudyAiProvider.openai => 'OpenAI',
        StudyAiProvider.anthropic => 'Anthropic',
      };

  String get keyHint => switch (this) {
        StudyAiProvider.openai => 'OpenAI secret',
        StudyAiProvider.anthropic => 'Anthropic secret',
      };

  String get defaultModel => switch (this) {
        StudyAiProvider.openai => 'gpt-4o-mini',
        StudyAiProvider.anthropic => 'claude-sonnet-4-5',
      };

  static StudyAiProvider fromStorage(String? value) {
    return StudyAiProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StudyAiProvider.anthropic,
    );
  }

  static StudyAiProvider inferFromKey(String key) {
    if (key.startsWith('sk-ant-')) return StudyAiProvider.anthropic;
    return StudyAiProvider.openai;
  }
}

/// On-device Study AI options. Provider keys live on the proxy, not in the app.
class StudyAiSettings extends ChangeNotifier {
  StudyAiSettings();

  static const _providerKey = 'study_ai_provider';
  static const _secureKey = 'study_ai_api_key';
  static const _prefsFallbackKey = 'study_ai_api_key_fallback';
  static const _customFlagKey = 'study_ai_using_custom_key';
  static const _ttsSecureKey = 'study_ai_openai_tts_key';
  static const _ttsPrefsKey = 'study_ai_openai_tts_key_fallback';
  static const _ttsCustomFlagKey = 'study_ai_using_custom_tts_key';

  /// Where the app sends Study AI / TTS / realtime-session requests.
  static const proxyUrl = String.fromEnvironment(
    'STUDY_AI_PROXY_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  StudyAiProvider provider = StudyAiProvider.anthropic;
  String? _apiKey;
  String? _ttsOpenAiKey;
  bool _usingCustom = false;
  bool _usingCustomTts = false;
  bool ready = false;

  bool get usingCustomKey => _usingCustom;

  bool get usingCustomTtsKey => _usingCustomTts;

  bool get usesProxy => proxyUrl.trim().isNotEmpty && !_usingCustom;

  bool get usesSpeechProxy => proxyUrl.trim().isNotEmpty && !_usingCustomTts;

  /// True when Study AI can run (signed-in proxy, or a user-supplied key).
  bool get hasKey => usesProxy || (_apiKey != null && _apiKey!.trim().isNotEmpty);

  /// Custom key only. Never a bundled/default secret.
  String? get apiKey {
    if (_usingCustom) {
      final k = _apiKey?.trim() ?? '';
      return k.isEmpty ? null : k;
    }
    return null;
  }

  String? get openAiSpeechKey {
    if (_usingCustomTts && _isOpenAiKey(_ttsOpenAiKey)) {
      return _ttsOpenAiKey!.trim();
    }
    if (_usingCustom &&
        provider == StudyAiProvider.openai &&
        _isOpenAiKey(_apiKey)) {
      return _apiKey!.trim();
    }
    return null;
  }

  bool get hasOpenAiSpeech => usesSpeechProxy || openAiSpeechKey != null;

  bool get needsSeparateListenKey =>
      !usesSpeechProxy &&
      (provider != StudyAiProvider.openai || !_isOpenAiKey(_apiKey));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _usingCustom = prefs.getBool(_customFlagKey) ?? false;
    try {
      _apiKey = await _secure.read(key: _secureKey);
    } catch (_) {
      _apiKey = null;
    }
    _apiKey ??= prefs.getString(_prefsFallbackKey);
    try {
      _ttsOpenAiKey = await _secure.read(key: _ttsSecureKey);
    } catch (_) {
      _ttsOpenAiKey = null;
    }
    _ttsOpenAiKey ??= prefs.getString(_ttsPrefsKey);
    _usingCustomTts = prefs.getBool(_ttsCustomFlagKey) ?? false;
    if (!_usingCustomTts || !_isOpenAiKey(_ttsOpenAiKey)) {
      _ttsOpenAiKey = null;
      _usingCustomTts = false;
    }
    if (!_usingCustom || _apiKey == null || _apiKey!.trim().isEmpty) {
      _apiKey = null;
      _usingCustom = false;
      provider = StudyAiProviderX.fromStorage(prefs.getString(_providerKey));
    } else {
      provider = StudyAiProviderX.fromStorage(prefs.getString(_providerKey));
      if (_apiKey!.startsWith('sk-ant-')) {
        provider = StudyAiProvider.anthropic;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> setProvider(StudyAiProvider next) async {
    provider = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, next.id);
    notifyListeners();
  }

  Future<void> setApiKey(String raw) async {
    final key = raw.trim();
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await _clearStoredKey();
      _apiKey = null;
      _usingCustom = false;
      await prefs.setBool(_customFlagKey, false);
      notifyListeners();
      return;
    }
    _apiKey = key;
    _usingCustom = true;
    if ((_apiKey!.startsWith('sk-ant-') &&
            provider != StudyAiProvider.anthropic) ||
        (!_apiKey!.startsWith('sk-ant-') &&
            _apiKey!.startsWith('sk-') &&
            provider != StudyAiProvider.openai)) {
      provider = StudyAiProviderX.inferFromKey(_apiKey!);
    }
    await prefs.setString(_providerKey, provider.id);
    await prefs.setBool(_customFlagKey, true);
    try {
      await _secure.write(key: _secureKey, value: _apiKey);
      await prefs.remove(_prefsFallbackKey);
    } catch (_) {
      await prefs.setString(_prefsFallbackKey, _apiKey!);
    }
    notifyListeners();
  }

  Future<void> setTtsOpenAiKey(String raw) async {
    final key = raw.trim();
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      _ttsOpenAiKey = null;
      _usingCustomTts = false;
      try {
        await _secure.delete(key: _ttsSecureKey);
      } catch (_) {}
      await prefs.remove(_ttsPrefsKey);
      await prefs.setBool(_ttsCustomFlagKey, false);
      notifyListeners();
      return;
    }
    if (!_isOpenAiKey(key)) {
      throw ListenKeyException(
        'Listen voices need an OpenAI key, not an Anthropic key.',
      );
    }
    _ttsOpenAiKey = key;
    _usingCustomTts = true;
    await prefs.setBool(_ttsCustomFlagKey, true);
    try {
      await _secure.write(key: _ttsSecureKey, value: key);
      await prefs.remove(_ttsPrefsKey);
    } catch (_) {
      await prefs.setString(_ttsPrefsKey, key);
    }
    notifyListeners();
  }

  static bool _isOpenAiKey(String? key) {
    final k = key?.trim() ?? '';
    return k.startsWith('sk-') && !k.startsWith('sk-ant-');
  }

  Future<void> _clearStoredKey() async {
    try {
      await _secure.delete(key: _secureKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsFallbackKey);
  }

  Future<void> resetToBundled() => setApiKey('');

  Future<void> clear() async {
    await resetToBundled();
    await setTtsOpenAiKey('');
  }
}

final studyAiSettings = StudyAiSettings();

class ListenKeyException implements Exception {
  ListenKeyException(this.message);
  final String message;
  @override
  String toString() => message;
}
