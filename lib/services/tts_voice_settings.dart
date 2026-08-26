import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsVoiceChoice {
  const TtsVoiceChoice({
    required this.name,
    required this.locale,
    this.gender,
  });

  final String name;
  final String locale;
  final String? gender;

  Map<String, String> get asMap => {'name': name, 'locale': locale};

  String get label {
    final localeBit = locale.replaceAll('_', '-');
    if (gender == null || gender == 'unknown') return '$name  ·  $localeBit';
    return '$name  ·  $localeBit  ·  $gender';
  }

  bool get isEnglish =>
      locale.toLowerCase().startsWith('en') ||
      locale.toLowerCase().startsWith('en-') ||
      locale.toLowerCase().startsWith('en_');
}

/// Remembers the TTS voice the student picked.
class TtsVoiceSettings extends ChangeNotifier {
  TtsVoiceSettings();

  static const _nameKey = 'tts_voice_name';
  static const _localeKey = 'tts_voice_locale';

  String? name;
  String? locale;

  bool get hasChoice => (name ?? '').isNotEmpty && (locale ?? '').isNotEmpty;

  Map<String, String>? get asMap {
    if (!hasChoice) return null;
    return {'name': name!, 'locale': locale!};
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString(_nameKey);
    locale = prefs.getString(_localeKey);
    notifyListeners();
  }

  Future<void> save(TtsVoiceChoice choice) async {
    name = choice.name;
    locale = choice.locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, choice.name);
    await prefs.setString(_localeKey, choice.locale);
    notifyListeners();
  }

  static List<TtsVoiceChoice> parse(dynamic raw) {
    if (raw is! List) return const [];
    final out = <TtsVoiceChoice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final n = (map['name'] ?? '').toString().trim();
      final loc = (map['locale'] ?? '').toString().trim();
      if (n.isEmpty || loc.isEmpty) continue;
      out.add(
        TtsVoiceChoice(
          name: n,
          locale: loc,
          gender: (map['gender'] as String?)?.trim(),
        ),
      );
    }
    out.sort((a, b) {
      final en = (a.isEnglish ? 0 : 1).compareTo(b.isEnglish ? 0 : 1);
      if (en != 0) return en;
      return a.name.compareTo(b.name);
    });
    return out;
  }
}

final ttsVoiceSettings = TtsVoiceSettings();
