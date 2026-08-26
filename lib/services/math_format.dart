/// Turns slash-style math into stacked TeX, and TeX into spoken “over” form.
class MathFormat {
  MathFormat._();

  static final _mathBlock = RegExp(
    r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\$([^$\n]+?)\$|\\\((.+?)\\\)',
  );

  static final _slashFrac = RegExp(
    r'(?<![A-Za-z0-9])'
    r'((?:\([^()\n]{1,48}\)|[A-Za-z\\][A-Za-z0-9_\\]*|\d+(?:\.\d+)?))'
    r'/'
    r'((?:\([^()\n]{1,48}\)|[A-Za-z\\][A-Za-z0-9_\\]*|\d+(?:\.\d+)?))'
    r'(?![A-Za-z0-9])',
  );

  static const _skipWords = {
    'and',
    'or',
    'to',
    'the',
    'of',
    'in',
    'on',
    'at',
    'for',
    'per',
    'http',
    'https',
  };

  /// Inserts `$...$` around converted fractions so [MathText] can render them.
  static String forDisplay(String raw) {
    if (raw.trim().isEmpty) return raw;
    final buf = StringBuffer();
    var cursor = 0;
    for (final match in _mathBlock.allMatches(raw)) {
      buf.write(_decorateProse(raw.substring(cursor, match.start)));
      buf.write(match[0]);
      cursor = match.end;
    }
    buf.write(_decorateProse(raw.substring(cursor)));
    return buf.toString();
  }

  /// Converts slash fractions that are already inside a TeX body.
  static String stackedTex(String tex) {
    if (tex.contains(r'\frac')) return tex;
    return tex.replaceAllMapped(_slashFrac, (m) {
      final a = m[1]!;
      final b = m[2]!;
      if (_skipWords.contains(a.toLowerCase()) ||
          _skipWords.contains(b.toLowerCase())) {
        return m[0]!;
      }
      return '\\frac{${_atom(a)}}{${_atom(b)}}';
    });
  }
  static String forSpeech(String raw) {
    var s = forDisplay(raw);
    s = s.replaceAllMapped(_mathBlock, (m) {
      final tex = (m[1] ?? m[2] ?? m[3] ?? m[4] ?? '').trim();
      return ' ${_speakTex(tex)} ';
    });
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '${_speakTex(m[1]!)} over ${_speakTex(m[2]!)}',
    );
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decorateProse(String prose) {
    var s = prose.replaceAllMapped(_slashFrac, (m) {
      final a = m[1]!;
      final b = m[2]!;
      if (_skipWords.contains(a.toLowerCase()) ||
          _skipWords.contains(b.toLowerCase())) {
        return m[0]!;
      }
      return '\$\\frac{${_atom(a)}}{${_atom(b)}}\$';
    });
    s = s.replaceAllMapped(
      RegExp(r'(?<![\$\\])\\frac\s*\{[^{}]+\}\s*\{[^{}]+\}'),
      (m) => '\$${m[0]}\$',
    );
    return s;
  }

  static String _atom(String s) {
    final t = s.trim();
    if (t.startsWith('(') && t.endsWith(')') && t.length >= 2) {
      return t.substring(1, t.length - 1);
    }
    return t;
  }

  static String _speakTex(String tex) {
    var s = tex;
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '${_speakTex(m[1]!)} over ${_speakTex(m[2]!)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\s*\{([^{}]+)\}'),
      (m) => 'square root of ${_speakTex(m[1]!)}',
    );
    s = s.replaceAll(r'\cdot', ' times ');
    s = s.replaceAll(r'\times', ' times ');
    s = s.replaceAll(r'\div', ' divided by ');
    s = s.replaceAll(r'\pi', ' pi ');
    s = s.replaceAll(r'\Delta', ' delta ');
    s = s.replaceAll(r'\theta', ' theta ');
    s = s.replaceAll(r'\lambda', ' lambda ');
    s = s.replaceAll(r'\alpha', ' alpha ');
    s = s.replaceAll(r'\beta', ' beta ');
    s = s.replaceAll(r'\omega', ' omega ');
    s = s.replaceAll(r'\sum', ' sum of ');
    s = s.replaceAll(r'\int', ' integral of ');
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ');
    s = s.replaceAll(RegExp(r'[{}^_]+'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

const mathAndConceptInstructions = '''
Write conceptually in words first: what the idea means, why it matters, and when you would use it.
Never leave a topic as bare letters or a lone formula (not "F=ma", not "a/b", not "x").
Any formula uses LaTeX inside \$...\$ (inline) or \$\$...\$\$ (block).
Fractions must be stacked as \$\\frac{numerator}{denominator}\$ — never slash form like a/b.
Name each symbol in words beside the formula.
''';
