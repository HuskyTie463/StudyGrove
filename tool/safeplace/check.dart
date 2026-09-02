/// Safeplace — local secret-leak checker for Study Grove.
///
/// Prints file path + secret TYPE only. Never prints values.
/// Does not upload anything. Bind address for --serve is 127.0.0.1 only.
///
/// From the repo root (prefer the Python checker on Windows; `dart run` hits Flutter hooks):
///   python tool/safeplace/check.py
///   dart tool/safeplace/check.dart
///   python tool/safeplace/check.py --serve
/// Then open http://127.0.0.1:8765
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) async {
  stdout.writeln('Scanning... (values are never printed)');
  final root = _repoRoot();
  final serve = args.contains('--serve');
  final report = await scan(root);

  if (serve) {
    await _serve(report);
    return;
  }
  stdout.write(report.toPlainText());
  exit(report.hasCritical ? 1 : 0);
}

Directory _repoRoot() {
  final script = File.fromUri(Platform.script);
  // tool/safeplace/check.dart → repo root
  return script.parent.parent.parent;
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

class Finding {
  Finding({
    required this.path,
    required this.type,
    required this.where,
    this.severity = 'critical',
    this.note,
  });

  final String path;
  final String type;
  final String where;
  final String severity;
  final String? note;

  String get key => '$severity|$type|$path|$where';
}

class Report {
  Report(this.root, this.findings, this.scannedFiles, this.scannedBinaries);

  final String root;
  final List<Finding> findings;
  final int scannedFiles;
  final int scannedBinaries;

  bool get hasCritical => findings.any((f) => f.severity == 'critical');

  String toPlainText() {
    final buf = StringBuffer();
    buf.writeln('Safeplace scan  (values are never printed)');
    buf.writeln('Root: $root');
    buf.writeln(
      'Scanned $scannedFiles text files, $scannedBinaries binaries/artifacts.',
    );
    buf.writeln('');
    if (findings.isEmpty) {
      buf.writeln('No matching secrets found.');
      return buf.toString();
    }
    final critical = findings.where((f) => f.severity == 'critical').toList();
    final info = findings.where((f) => f.severity != 'critical').toList();
    if (critical.isNotEmpty) {
      buf.writeln('CRITICAL — extractable / signing material');
      for (final f in critical) {
        buf.writeln('  ${f.type}  in  ${f.path}  [${f.where}]');
        if (f.note != null) buf.writeln('    ${f.note}');
      }
      buf.writeln('');
    }
    if (info.isNotEmpty) {
      buf.writeln('INFO — expected in client apps (not Apple/AI private keys)');
      for (final f in info) {
        buf.writeln('  ${f.type}  in  ${f.path}  [${f.where}]');
        if (f.note != null) buf.writeln('    ${f.note}');
      }
    }
    return buf.toString();
  }

  Map<String, Object?> toJson() => {
        'root': root,
        'scannedFiles': scannedFiles,
        'scannedBinaries': scannedBinaries,
        'hasCritical': hasCritical,
        'findings': [
          for (final f in findings)
            {
              'path': f.path,
              'type': f.type,
              'where': f.where,
              'severity': f.severity,
              if (f.note != null) 'note': f.note,
            },
        ],
      };
}

// ---------------------------------------------------------------------------
// Patterns — match enough to classify; never echo the match
// ---------------------------------------------------------------------------

// Split prefixes so this file is not itself a false-positive hit.
final _anthropic = RegExp('sk-' r'ant-[A-Za-z0-9_-]{24,}');
final _openai = RegExp('sk-' r'(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}');
final _pemPrivate = RegExp(
  '-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE' ' KEY-----',
);
final _awsAccess = RegExp(r'AKIA[0-9A-Z]{16}');
final _githubPat = RegExp(r'(?:ghp|gho|ghu|ghs)_[A-Za-z0-9]{20,}');
final _githubFine = RegExp(r'github_pat_[A-Za-z0-9_]{20,}');
final _stripeLive = RegExp(r'sk_live_[A-Za-z0-9]{16,}');
final _stripeTest = RegExp(r'sk_test_[A-Za-z0-9]{16,}');
final _googleOauth = RegExp(r'GOCSPX-[A-Za-z0-9_-]{10,}');
final _firebaseClient = RegExp(r'AIzaSy[A-Za-z0-9_-]{20,}');
final _serviceAccountType = RegExp(r'"type"\s*:\s*"service_account"');
final _serviceAccountPk = RegExp(r'"private_key"\s*:');

const _signingExts = {
  '.p8',
  '.p12',
  '.pfx',
  '.key',
  '.mobileprovision',
  '.provisionprofile',
  '.cer',
  '.certsigningrequest',
};

const _binaryExts = {
  '.exe',
  '.dll',
  '.so',
  '.dylib',
  '.a',
  '.apk',
  '.aab',
  '.ipa',
  '.app',
  '.bin',
  '.dat',
  '.snapshot',
};

const _skipDirNames = {
  '.git',
  '.dart_tool',
  '.pub-cache',
  '.pub',
  '.venv',
  'node_modules',
  'pods',
  'ephemeral',
  'cmakeFiles',
  'obj',
  '.idea',
  '.vs',
  'coverage',
};

const _skipFileNames = {
  'flutter_windows.dll',
  'flutter_windows.dll.pdb',
};

bool _skipDir(String name) {
  final n = name.toLowerCase();
  if (_skipDirNames.contains(n)) return true;
  if (n.startsWith('cmakefiles')) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

Future<Report> scan(Directory root) async {
  final seen = <String>{};
  final findings = <Finding>[];
  var textCount = 0;
  var binCount = 0;

  void add(Finding f) {
    if (seen.add(f.key)) findings.add(f);
  }

  final files = <File>[];
  Future<void> walk(Directory dir) async {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final entity in entries) {
      if (entity is Directory) {
        if (_skipDir(entity.path.split(RegExp(r'[/\\]')).last)) continue;
        await walk(entity);
      } else if (entity is File) {
        final r = _rel(root, entity);
        if (_shouldSkipPath(r)) continue;
        files.add(entity);
      }
    }
  }

  await walk(root);
  final bundled = File('${root.path}${Platform.pathSeparator}.bundled_keys');
  if (bundled.existsSync()) files.add(bundled);

  for (final file in files) {
    final rel = _rel(root, file);
    final ext = _ext(file.path);
    if (_signingExts.contains(ext)) {
      add(Finding(
        path: rel,
        type: _signingType(ext, rel),
        where: 'working tree (file present)',
      ));
      continue;
    }
    if (_isProbablyBinaryPath(rel, ext)) {
      binCount++;
      try {
        final bytes = await file.readAsBytes();
        _scanBytes(bytes, rel, 'built artifact', add);
      } catch (_) {}
      continue;
    }
    int? size;
    try {
      size = await file.length();
    } catch (_) {
      continue;
    }
    if (size > 8 * 1024 * 1024) {
      binCount++;
      try {
        final bytes = await file.readAsBytes();
        _scanBytes(bytes, rel, 'large file', add);
      } catch (_) {}
      continue;
    }
    String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      try {
        final bytes = await file.readAsBytes();
        if (_looksBinary(bytes)) {
          binCount++;
          _scanBytes(bytes, rel, 'binary', add);
          continue;
        }
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        continue;
      }
    }
    if (text.contains('\u0000')) {
      binCount++;
      _scanBytes(Uint8List.fromList(utf8.encode(text)), rel, 'binary', add);
      continue;
    }
    textCount++;
    _scanText(text, rel, 'working tree', add);
  }

  await _scanGitHistory(root, add);

  findings.sort((a, b) {
    final s = a.severity.compareTo(b.severity);
    if (s != 0) return s;
    final t = a.type.compareTo(b.type);
    if (t != 0) return t;
    return a.path.compareTo(b.path);
  });

  return Report(root.path, findings, textCount, binCount);
}

bool _shouldSkipPath(String rel) {
  final parts = rel.split(RegExp(r'[/\\]'));
  for (final p in parts) {
    if (_skipDir(p)) return true;
  }
  final name = parts.isEmpty ? rel : parts.last.toLowerCase();
  if (_skipFileNames.contains(name)) return true;
  if (name.endsWith('.pdb') || name.endsWith('.ilk') || name.endsWith('.obj')) {
    return true;
  }
  if (name.endsWith('.map.json') || name.endsWith('.symbols')) return true;
  return false;
}

bool _isProbablyBinaryPath(String rel, String ext) {
  if (_binaryExts.contains(ext)) return true;
  final lower = rel.replaceAll('\\', '/').toLowerCase();
  if (lower.contains('/runner/release/') &&
      (ext.isEmpty || ext == '.exe' || ext == '.dll')) {
    return true;
  }
  if (lower.endsWith('/studygrove') && !lower.contains('.')) return true;
  return false;
}

String _signingType(String ext, String rel) {
  final name = rel.toLowerCase();
  switch (ext) {
    case '.p8':
      return 'Apple AuthKey / .p8 private key file';
    case '.p12':
    case '.pfx':
      return 'PKCS#12 signing certificate (.p12)';
    case '.mobileprovision':
    case '.provisionprofile':
      return 'Apple provisioning profile';
    case '.cer':
      return 'Apple certificate (.cer)';
    case '.key':
      return 'Private key file (.key)';
    case '.certsigningrequest':
      return 'Certificate signing request';
    default:
      return 'Signing material ($ext) in $name';
  }
}

void _scanText(
  String text,
  String path,
  String where,
  void Function(Finding) add,
) {
  if (_anthropic.hasMatch(text)) {
    add(Finding(path: path, type: 'Anthropic API key', where: where));
  }
  if (_openai.hasMatch(text) && !_onlyAnthropicSk(text)) {
    add(Finding(path: path, type: 'OpenAI API key', where: where));
  }
  if (_pemPrivate.hasMatch(text)) {
    add(Finding(
      path: path,
      type: 'PEM private key',
      where: where,
    ));
  }
  if (_serviceAccountType.hasMatch(text) && _serviceAccountPk.hasMatch(text)) {
    add(Finding(
      path: path,
      type: 'Google service-account JSON (private_key)',
      where: where,
    ));
  } else if (_serviceAccountPk.hasMatch(text) && _pemPrivate.hasMatch(text)) {
    add(Finding(
      path: path,
      type: 'JSON private_key field',
      where: where,
    ));
  }
  if (_awsAccess.hasMatch(text)) {
    add(Finding(path: path, type: 'AWS access key id', where: where));
  }
  if (_githubPat.hasMatch(text) || _githubFine.hasMatch(text)) {
    add(Finding(path: path, type: 'GitHub personal access token', where: where));
  }
  if (_stripeLive.hasMatch(text)) {
    add(Finding(path: path, type: 'Stripe live secret key', where: where));
  }
  if (_stripeTest.hasMatch(text)) {
    add(Finding(path: path, type: 'Stripe test secret key', where: where));
  }
  if (_googleOauth.hasMatch(text)) {
    add(Finding(path: path, type: 'Google OAuth client secret', where: where));
  }
  if (_firebaseClient.hasMatch(text)) {
    add(Finding(
      path: path,
      type: 'Firebase / Google client API key',
      where: where,
      severity: 'info',
      note: 'Expected in apps. Protect data with Firestore rules + API restrictions.',
    ));
  }
}

bool _onlyAnthropicSk(String text) {
  final opens = _openai.allMatches(text);
  if (opens.isEmpty) return true;
  for (final m in opens) {
    final slice = text.substring(m.start, m.end);
    if (!slice.startsWith('sk-ant-')) return false;
  }
  return true;
}

void _scanBytes(
  List<int> bytes,
  String path,
  String where,
  void Function(Finding) add,
) {
  // ASCII / UTF-8 needles only — never construct a printable secret.
  final antNeedle = 'sk-' 'ant-';
  final projNeedle = 'sk-' 'proj-';
  _findAscii(bytes, antNeedle, (i) {
    if (_looksLikeKeyTail(bytes, i + antNeedle.length, 24)) {
      add(Finding(path: path, type: 'Anthropic API key', where: where));
      return false;
    }
    return true;
  });
  _findAscii(bytes, projNeedle, (i) {
    if (_looksLikeKeyTail(bytes, i + projNeedle.length, 24)) {
      add(Finding(path: path, type: 'OpenAI API key', where: where));
      return false;
    }
    return true;
  });
  _findAscii(bytes, 'sk-', (i) {
    if (_eqAsciiAt(bytes, i, antNeedle)) return true;
    if (_eqAsciiAt(bytes, i, projNeedle)) return true;
    if (_looksLikeKeyTail(bytes, i + 3, 32)) {
      add(Finding(path: path, type: 'OpenAI-like API key', where: where));
      return false;
    }
    return true;
  });
  if (_containsAscii(bytes, 'BEGIN PRIVATE' ' KEY') ||
      _containsAscii(bytes, 'BEGIN RSA PRIVATE' ' KEY')) {
    add(Finding(path: path, type: 'PEM private key', where: where));
  }
  _findAscii(bytes, 'AIzaSy', (i) {
    if (_looksLikeKeyTail(bytes, i + 6, 20)) {
      add(Finding(
        path: path,
        type: 'Firebase / Google client API key',
        where: where,
        severity: 'info',
        note: 'Expected in apps. Protect data with Firestore rules + API restrictions.',
      ));
      return false;
    }
    return true;
  });
}

bool _looksLikeKeyTail(List<int> bytes, int start, int minLen) {
  var n = 0;
  for (var i = start; i < bytes.length && n < minLen + 8; i++) {
    final c = bytes[i];
    final ok = (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        c == 45 ||
        c == 95;
    if (!ok) break;
    n++;
  }
  return n >= minLen;
}

bool _eqAsciiAt(List<int> bytes, int i, String needle) {
  if (i + needle.length > bytes.length) return false;
  for (var k = 0; k < needle.length; k++) {
    if (bytes[i + k] != needle.codeUnitAt(k)) return false;
  }
  return true;
}

bool _containsAscii(List<int> bytes, String needle) {
  var found = false;
  _findAscii(bytes, needle, (_) {
    found = true;
    return false;
  });
  return found;
}

void _findAscii(
  List<int> bytes,
  String needle,
  bool Function(int index) onHit,
) {
  final n = needle.codeUnits;
  if (n.isEmpty || bytes.length < n.length) return;
  final first = n[0];
  outer:
  for (var i = 0; i <= bytes.length - n.length; i++) {
    if (bytes[i] != first) continue;
    for (var k = 1; k < n.length; k++) {
      if (bytes[i + k] != n[k]) continue outer;
    }
    if (!onHit(i)) return;
  }
}

bool _looksBinary(List<int> bytes) {
  final n = bytes.length < 2048 ? bytes.length : 2048;
  var nul = 0;
  for (var i = 0; i < n; i++) {
    if (bytes[i] == 0) nul++;
  }
  return nul > 8;
}

// ---------------------------------------------------------------------------
// Git history (names + types only; git grep -l never prints line content)
// ---------------------------------------------------------------------------

Future<void> _scanGitHistory(
  Directory root,
  void Function(Finding) add,
) async {
  if (!await Directory('${root.path}/.git').exists()) return;

  // History: list files whose diffs match; never pass -p (that would print values).
  await _historyPickaxe(
    root,
    'sk-' 'ant-api',
    'Anthropic API key',
    add,
  );
  await _historyPickaxe(
    root,
    'sk-' 'proj-',
    'OpenAI API key',
    add,
  );
  await _historyPickaxe(
    root,
    'BEGIN PRIVATE' ' KEY',
    'PEM private key',
    add,
  );
  await _historyPickaxe(
    root,
    r'"type": "service_account"',
    'Google service-account JSON (private_key)',
    add,
  );

  // Signing files that were ever tracked.
  final histFiles = await Process.run(
    'git',
    [
      'log',
      '--all',
      '--name-only',
      '--pretty=format:',
      '--',
      '*.p8',
      '*.p12',
      '*.pfx',
      '*.mobileprovision',
      '*.provisionprofile',
    ],
    workingDirectory: root.path,
  );
  if (histFiles.exitCode == 0) {
    for (final line
        in const LineSplitter().convert(histFiles.stdout.toString())) {
      final path = line.trim();
      if (path.isEmpty) continue;
      add(Finding(
        path: path,
        type: _signingType(_ext(path), path),
        where: 'git history (filename tracked)',
      ));
    }
  }
}

Future<void> _historyPickaxe(
  Directory root,
  String regex,
  String type,
  void Function(Finding) add,
) async {
  final r = await Process.run(
    'git',
    [
      'log',
      '--all',
      '-S',
      regex,
      '--name-only',
      '--pretty=format:',
    ],
    workingDirectory: root.path,
  );
  if (r.exitCode != 0) return;
  for (final line in const LineSplitter().convert(r.stdout.toString())) {
    final path = line.trim();
    if (path.isEmpty) continue;
    if (path.startsWith('commit ')) continue;
    add(Finding(path: path, type: type, where: 'git history'));
  }
}

String _rel(Directory root, File file) {
  final rootPath = root.path.replaceAll('\\', '/');
  var p = file.path.replaceAll('\\', '/');
  if (p.startsWith(rootPath)) {
    p = p.substring(rootPath.length);
    if (p.startsWith('/')) p = p.substring(1);
  }
  return p;
}

String _ext(String path) {
  final base = path.split(RegExp(r'[/\\]')).last;
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return '';
  return base.substring(dot).toLowerCase();
}

// ---------------------------------------------------------------------------
// Localhost report server
// ---------------------------------------------------------------------------

Future<void> _serve(Report report) async {
  HttpServer? server;
  const preferred = 8765;
  for (final port in [preferred, 8766, 8767]) {
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      break;
    } on SocketException {
      continue;
    }
  }
  if (server == null) {
    stderr.writeln('Could not bind 127.0.0.1:8765-8767');
    exit(2);
  }
  final url = 'http://127.0.0.1:${server.port}/';
  stdout.writeln('Safeplace is local-only. Open $url');
  stdout.writeln('Stop with Ctrl+C. Nothing is uploaded.');
  await for (final req in server) {
    try {
      if (req.method == 'GET' && req.uri.path == '/report.json') {
        final body = jsonEncode(report.toJson());
        req.response
          ..headers.contentType = ContentType.json
          ..headers.set('Cache-Control', 'no-store')
          ..write(body);
      } else {
        req.response
          ..headers.contentType = ContentType.html
          ..headers.set('Cache-Control', 'no-store')
          ..write(_html(report));
      }
    } finally {
      await req.response.close();
    }
  }
}

String _html(Report r) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  final rows = r.findings.map((f) {
    final cls = f.severity == 'critical' ? 'crit' : 'info';
    final note = f.note == null
        ? ''
        : '<div class="note">${esc(f.note!)}</div>';
    return '<tr class="$cls"><td>${esc(f.severity)}</td>'
        '<td>${esc(f.type)}$note</td><td><code>${esc(f.path)}</code></td>'
        '<td>${esc(f.where)}</td></tr>';
  }).join();

  final empty = r.findings.isEmpty
      ? '<p>No matching secrets found.</p>'
      : '';

  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Safeplace</title>
<style>
  body { font-family: ui-sans-serif, system-ui, sans-serif; margin: 2rem; background: #0f1410; color: #e8efe6; }
  h1 { font-size: 1.4rem; }
  .sub { color: #9aab96; margin-bottom: 1.5rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; padding: .5rem .6rem; border-bottom: 1px solid #2a3328; vertical-align: top; }
  code { font-size: .9rem; }
  tr.crit td:first-child { color: #ffb4a8; }
  tr.info td:first-child { color: #9ad4aa; }
  .note { color: #9aab96; font-size: .85rem; margin: 0 0 .8rem .6rem; }
  .ok { color: #9ad4aa; }
</style>
</head>
<body>
  <h1>Safeplace</h1>
  <p class="sub">Local leak check. Types and paths only — values are never shown. This page is 127.0.0.1 only.</p>
  <p>Scanned ${r.scannedFiles} text files and ${r.scannedBinaries} binaries under <code>${esc(r.root)}</code>.</p>
  $empty
  ${r.findings.isEmpty ? '' : '''
  <table>
    <thead><tr><th>Level</th><th>Type</th><th>Path</th><th>Where</th></tr></thead>
    <tbody>$rows</tbody>
  </table>
  '''}
</body>
</html>''';
}
