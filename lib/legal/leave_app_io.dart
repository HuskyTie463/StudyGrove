import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Closes the app without recording licence acceptance.
void leaveStudyGrove() {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    exit(0);
  }
  SystemNavigator.pop();
}
