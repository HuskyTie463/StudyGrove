import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StudyRouletteStore {
  static const _kProgress = 'study_roulette_next_reward_progress';
  static const _kRewards = 'study_roulette_mystery_rewards_json';

  static const defaultRewards = [
    '10-minute walk outside',
    'One episode guilt-free',
    'Call or message someone you like',
    'A small treat you choose',
    '15-minute scroll break (timer on)',
    'Stretch + water break',
  ];

  Future<int> progressTowardReward() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getInt(_kProgress);
    var v = raw ?? 0;
    if (raw != null && (raw < 0 || raw > 2)) {
      v = 0;
      await p.setInt(_kProgress, 0);
    }
    return v.clamp(0, 2);
  }

  /// Returns `true` if a mystery reward was unlocked (3rd completion).
  Future<bool> completeChallenge() async {
    final p = await SharedPreferences.getInstance();
    var cur = p.getInt(_kProgress);
    if (cur != null && (cur < 0 || cur > 2)) {
      cur = 0;
      await p.setInt(_kProgress, 0);
    }
    final base = (cur ?? 0).clamp(0, 2);
    int n = base + 1;
    if (n >= 3) {
      await p.setInt(_kProgress, 0);
      return true;
    }
    await p.setInt(_kProgress, n);
    return false;
  }

  Future<List<String>> loadRewards() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kRewards);
    if (s == null || s.isEmpty) return List<String>.from(defaultRewards);
    try {
      final list = jsonDecode(s) as List<dynamic>;
      final out = list.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
      return out.isEmpty ? List<String>.from(defaultRewards) : out;
    } catch (_) {
      return List<String>.from(defaultRewards);
    }
  }

  Future<void> saveRewards(List<String> rewards) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = rewards.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await p.setString(_kRewards, jsonEncode(trimmed));
  }
}
