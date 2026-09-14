import 'package:package_info_plus/package_info_plus.dart';

/// Reads the running app version for licence acceptance records.
Future<String> readAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isEmpty) return info.version;
    return '${info.version}+$build';
  } catch (_) {
    return '1.0.6';
  }
}
