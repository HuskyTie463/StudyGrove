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
        StudyAiProvider.openai => 'sk-…',
        StudyAiProvider.anthropic => 'sk-ant-…',
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

/// Stores the user's API key on-device. Never sent to Firestore.
class StudyAiSettings extends ChangeNotifier {
  StudyAiSettings();

  static const _providerKey = 'study_ai_provider';
  static const _secureKey = 'study_ai_api_key';
  static const _prefsFallbackKey = 'study_ai_api_key_fallback';
  static const _customFlagKey = 'study_ai_using_custom_key';
  static const _ttsSecureKey = 'study_ai_openai_tts_key';
  static const _ttsPrefsKey = 'study_ai_openai_tts_key_fallback';
  static const _ttsCustomFlagKey = 'study_ai_using_custom_tts_key';

  /// Optional Study AI key from Settings. There is no bundled cloud key in source.
  static const bundledKey = '';

  /// Optional OpenAI Listen/Voice key from Settings.
  static const bundledOpenAiTtsKey = '';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  StudyAiProvider provider = StudyAiProvider.anthropic;
  String? _apiKey;
  String? _ttsOpenAiKey;
  bool _usingCustom = false;
  bool _usingCustomTts = false;
  bool ready = false;

  bool get hasKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  bool get usingCustomKey => _usingCustom;

  String? get apiKey => _apiKey;

  bool get usingCustomTtsKey => _usingCustomTts;

  /// OpenAI key used for Listen neural speech. Reuses Study AI when that
  /// provider is already OpenAI; otherwise the Listen key (custom or built-in).
  String? get openAiSpeechKey {
    if (provider == StudyAiProvider.openai && _isOpenAiKey(_apiKey)) {
      return _apiKey!.trim();
    }
    if (_isOpenAiKey(_ttsOpenAiKey)) return _ttsOpenAiKey!.trim();
    return _isOpenAiKey(bundledOpenAiTtsKey) ? bundledOpenAiTtsKey : null;
  }

  bool get hasOpenAiSpeech => openAiSpeechKey != null;

  bool get needsSeparateListenKey =>
      provider != StudyAiProvider.openai || !_isOpenAiKey(_apiKey);

  String get maskedTtsKey {
    final k = openAiSpeechKey ?? '';
    if (k.length < 8) return hasOpenAiSpeech ? '••••' : '';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  String get maskedKey {
    final k = _apiKey?.trim() ?? '';
    if (k.length < 8) return hasKey ? '••••' : '';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

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
      _ttsOpenAiKey = _isOpenAiKey(bundledOpenAiTtsKey) ? bundledOpenAiTtsKey : null;
      _usingCustomTts = false;
    }
    if (_apiKey == null || _apiKey!.trim().isEmpty || !_usingCustom) {
      _apiKey = bundledKey.trim().isEmpty ? null : bundledKey;
      _usingCustom = false;
      if (_apiKey != null) {
        provider = StudyAiProvider.anthropic;
      } else {
        provider = StudyAiProviderX.fromStorage(prefs.getString(_providerKey));
      }
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
      _apiKey = bundledKey.trim().isEmpty ? null : bundledKey;
      _usingCustom = false;
      provider = StudyAiProvider.anthropic;
      await prefs.setBool(_customFlagKey, false);
      await prefs.setString(_providerKey, provider.id);
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
      _ttsOpenAiKey = _isOpenAiKey(bundledOpenAiTtsKey) ? bundledOpenAiTtsKey : null;
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
        'Listen voices need an OpenAI key (starts with sk-, not sk-ant-).',
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

  /// Drop a custom key.
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
