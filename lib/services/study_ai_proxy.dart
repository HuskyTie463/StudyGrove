import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'study_ai_client.dart';
import 'study_ai_settings.dart';

/// Talks to the in-repo Study Grove proxy. Provider keys never leave the server.
class StudyAiProxy {
  StudyAiProxy._();

  static String get baseUrl {
    final raw = StudyAiSettings.proxyUrl.trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  static bool get configured => baseUrl.isNotEmpty;

  static Uri uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  static Future<Map<String, String>> headers({
    Map<String, String> extra = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StudyAiException('Sign in to use Study AI.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...extra,
    };
  }

  static Future<http.Response> post(
    String path, {
    required Object body,
    Map<String, String> extraHeaders = const {},
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final encoded = body is String ? body : jsonEncode(body);
    try {
      return await http
          .post(
            uri(path),
            headers: await headers(extra: extraHeaders),
            body: encoded,
          )
          .timeout(timeout);
    } on SocketException {
      throw StudyAiException(
        'Could not reach the Study AI server at $baseUrl. Start it on this computer (see server/README.md), or set STUDY_AI_PROXY_URL.',
      );
    } on HttpException {
      throw StudyAiException(
        'Could not reach the Study AI server. Check the proxy is running.',
      );
    }
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    required Object body,
    Map<String, String> extraHeaders = const {},
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final res = await post(
      path,
      body: body,
      extraHeaders: extraHeaders,
      timeout: timeout,
    );
    return decode(res);
  }

  static Map<String, dynamic> decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw StudyAiException(
        'Study AI server returned a non-JSON error (${res.statusCode}).',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StudyAiException(_errorFrom(data, res.statusCode));
    }
    return data;
  }

  static String _errorFrom(Map<String, dynamic> data, int status) {
    final err = data['error'];
    if (err is Map && err['message'] is String) {
      return err['message'] as String;
    }
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (data['message'] is String) return data['message'] as String;
    if (status == 401) return 'Sign in again to use Study AI.';
    if (status == 503) {
      return 'Study AI is not configured on the server yet.';
    }
    if (status == 429) return 'Rate limited. Try again in a moment.';
    return 'Study AI server error ($status).';
  }
}
