/// Turns slash-style math into stacked TeX, and TeX into spoken “over” form.
class MathFormat {
  MathFormat._();

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

  static const _displayEnvs = {
    'equation',
    'equation*',
    'align',
    'align*',
    'aligned',
    'gather',
    'gather*',
    'eqnarray',
    'eqnarray*',
    'multline',
    'multline*',
  };

  /// Inserts `$...$` around converted fractions so [MathText] can render them.
  static String forDisplay(String raw) {
    if (raw.trim().isEmpty) return raw;
    final buf = StringBuffer();
    for (final span in scan(raw)) {
      if (span.isMath) {
        buf.write(span.raw);
      } else {
        buf.write(_decorateProse(span.prose));
      }
    }
    return buf.toString();
  }

  /// Converts slash fractions that are already inside a TeX body.
  static String stackedTex(String tex) {
    var s = sanitizeTex(tex);
    if (s.contains(r'\frac')) return s;
    return s.replaceAllMapped(_slashFrac, (m) {
      final a = m[1]!;
      final b = m[2]!;
      if (_skipWords.contains(a.toLowerCase()) ||
          _skipWords.contains(b.toLowerCase())) {
        return m[0]!;
      }
      return '\\frac{${_atom(a)}}{${_atom(b)}}';
    });
  }

  /// Makes TeX more likely to parse in flutter_math_fork.
  static String sanitizeTex(String tex) {
    var s = tex.trim();
    s = s.replaceAll(r'\dfrac', r'\frac');
    s = s.replaceAll(r'\tfrac', r'\frac');
    s = s.replaceAll(RegExp(r'\\displaystyle\s*'), '');
    s = s.replaceAll(RegExp(r'\\textstyle\s*'), '');
    s = s.replaceAll(RegExp(r'\\limits\s*'), '');
    s = s.replaceAll(RegExp(r'\\nolimits\s*'), '');
    s = s.replaceAllMapped(
      RegExp(
        r'\\begin\{(equation\*?|align\*?|aligned|gather\*?|eqnarray\*?|multline\*?)\}',
      ),
      (_) => '',
    );
    s = s.replaceAllMapped(
      RegExp(
        r'\\end\{(equation\*?|align\*?|aligned|gather\*?|eqnarray\*?|multline\*?)\}',
      ),
      (_) => '',
    );
    s = s.replaceAll(RegExp(r'\s*&=\s*'), ' = ');
    s = s.replaceAll('&', ' ');
    return s.trim();
  }

  static String forSpeech(String raw) {
    var s = forDisplay(raw);
    final buf = StringBuffer();
    for (final span in scan(s)) {
      if (span.isMath) {
        buf.write(' ${_speakTex(span.tex!)} ');
      } else {
        buf.write(span.prose);
      }
    }
    s = buf.toString();
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '${_speakTex(m[1]!)} over ${_speakTex(m[2]!)}',
    );
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Walks [raw] in document order: prose vs math (`$`, `$$`, `\(...\)`, `\[...\]`, environments).
  static List<MathSpan> scan(String raw) {
    final out = <MathSpan>[];
    final prose = StringBuffer();
    var i = 0;
    final n = raw.length;

    void flushProse() {
      if (prose.isEmpty) return;
      out.add(MathSpan.prose(prose.toString()));
      prose.clear();
    }

    bool at(String lit) => i + lit.length <= n && raw.startsWith(lit, i);

    while (i < n) {
      if (raw[i] == r'\' && i + 1 < n && raw[i + 1] == r'$') {
        prose.write(r'$');
        i += 2;
        continue;
      }

      if (at(r'$$')) {
        final end = raw.indexOf(r'$$', i + 2);
        if (end != -1) {
          flushProse();
          final tex = raw.substring(i + 2, end).trim();
          if (tex.isNotEmpty) {
            out.add(MathSpan.math(tex, display: true, raw: raw.substring(i, end + 2)));
          }
          i = end + 2;
          continue;
        }
      }

      if (at(r'\[')) {
        final end = raw.indexOf(r'\]', i + 2);
        if (end != -1) {
          flushProse();
          final tex = raw.substring(i + 2, end).trim();
          if (tex.isNotEmpty) {
            out.add(MathSpan.math(tex, display: true, raw: raw.substring(i, end + 2)));
          }
          i = end + 2;
          continue;
        }
      }

      if (at(r'\begin{')) {
        final brace = raw.indexOf('}', i + 7);
        if (brace != -1) {
          final env = raw.substring(i + 7, brace);
          if (_displayEnvs.contains(env)) {
            final closer = '\\end{$env}';
            final end = raw.indexOf(closer, brace + 1);
            if (end != -1) {
              flushProse();
              final stop = end + closer.length;
              final tex = raw.substring(i, stop).trim();
              if (tex.isNotEmpty) {
                out.add(MathSpan.math(tex, display: true, raw: raw.substring(i, stop)));
              }
              i = stop;
              continue;
            }
          }
        }
      }

      if (at(r'\(')) {
        final end = raw.indexOf(r'\)', i + 2);
        if (end != -1) {
          flushProse();
          final tex = raw.substring(i + 2, end).trim();
          if (tex.isNotEmpty) {
            out.add(MathSpan.math(tex, display: false, raw: raw.substring(i, end + 2)));
          }
          i = end + 2;
          continue;
        }
      }

      if (raw[i] == r'$') {
        var j = i + 1;
        var found = false;
        while (j < n) {
          if (raw[j] == '\n') break;
          if (raw[j] == r'$' && raw[j - 1] != r'\') {
            found = true;
            break;
          }
          j++;
        }
        if (found && j > i + 1) {
          flushProse();
          final tex = raw.substring(i + 1, j).trim();
          if (tex.isNotEmpty) {
            out.add(MathSpan.math(tex, display: false, raw: raw.substring(i, j + 1)));
          }
          i = j + 1;
          continue;
        }
      }

      prose.write(raw[i]);
      i++;
    }
    flushProse();
    return out;
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
    var s = sanitizeTex(tex);
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

class MathSpan {
  const MathSpan._({
    required this.prose,
    required this.tex,
    required this.isDisplay,
    required this.raw,
  });

  factory MathSpan.prose(String s) => MathSpan._(
        prose: s,
        tex: null,
        isDisplay: false,
        raw: s,
      );

  factory MathSpan.math(
    String tex, {
    required bool display,
    required String raw,
  }) =>
      MathSpan._(prose: '', tex: tex, isDisplay: display, raw: raw);

  final String prose;
  final String? tex;
  final bool isDisplay;
  final String raw;

  bool get isMath => tex != null;
}

const mathAndConceptInstructions = '''
Write conceptually in words first: what the idea means, why it matters, and when you would use it.
Never leave a topic as bare letters or a lone formula (not "F=ma", not "a/b", not "x").
Any formula uses LaTeX inside \$...\$ (inline) or \$\$...\$\$ (block).
Fractions must be stacked as \$\\frac{numerator}{denominator}\$ — never slash form like a/b.
Name each symbol in words beside the formula.
''';
