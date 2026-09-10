import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pins the 2x2 Study Grove Android launcher widget when the OS supports it.
class AndroidHomeWidget {
  static const _channel = MethodChannel('com.adaracurry.studygrove/home_widget');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<String> requestPin() async {
    if (!isSupported) return 'unsupported';
    try {
      final raw = await _channel.invokeMethod<String>('pinHomeWidget');
      return raw ?? 'unsupported';
    } catch (_) {
      return 'unsupported';
    }
  }
}
