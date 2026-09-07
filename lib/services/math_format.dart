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
    final cleaned = normalizeRevisionText(raw);
    final buf = StringBuffer();
    for (final span in scan(cleaned)) {
      if (span.isMath) {
        buf.write(span.raw);
      } else {
        buf.write(_promoteTexChunks(_decorateProse(span.prose)));
      }
    }
    return buf.toString();
  }

  /// Doubles a lone JSON backslash before TeX words that JSON would eat
  /// (`\frac` → form-feed + `rac`). Safe for already-escaped `\\frac`.
  static String repairModelJson(String json) {
    return json.replaceAllMapped(
      RegExp(r'(?<!\\)\\([bfnrt][A-Za-z]+)'),
      (m) => '\\\\${m[1]}',
    );
  }

  /// Strips markdown chrome, unifies math delimiters, and tidies model junk
  /// so [scan] sees `$...$` / `$$...$$` instead of raw `\(` or `**bold**`.
  static String normalizeRevisionText(String raw) {
    var s = raw.replaceAll('\r\n', '\n');
    if (s.trim().isEmpty) return raw;

    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = _repairDecodedTex(s);

    // Models / JSON often write `\$...\$` — treat those as real delimiters.
    s = s.replaceAll(r'\\$', r'$');
    s = s.replaceAll(r'\$', r'$');

    // JSON / markdown leftovers: `\\frac` → `\frac`, `\\(` → `\(`
    s = s.replaceAll(r'\\(', r'\(');
    s = s.replaceAll(r'\\)', r'\)');
    s = s.replaceAll(r'\\[', r'\[');
    s = s.replaceAll(r'\\]', r'\]');
    s = s.replaceAllMapped(RegExp(r'\\+([a-zA-Z]+)'), (m) => '\\${m[1]}');

    s = s.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: true),
      (m) => '\$${m[1]!.trim()}\$',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]', dotAll: true),
      (m) => '\$\$${m[1]!.trim()}\$\$',
    );

    s = _closeUnpairedDollars(s);
    s = _mapOutsideMath(s, _stripMarkdown);
    s = _mapOutsideMath(s, _unicodeMathHints);
    s = s.replaceAll('**', '');
    s = s.replaceAll('__', '');
    return s;
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
    var s = stripMathDelimiters(tex);
    s = _repairDecodedTex(s);
    s = s.replaceAllMapped(RegExp(r'\\+([a-zA-Z]+)'), (m) => '\\${m[1]}');
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

  /// Drop leftover `$` / `\(`/`\[` so flutter_math_fork sees a math body.
  static String stripMathDelimiters(String tex) {
    var s = tex.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length > 4) {
      s = s.substring(2, s.length - 2).trim();
    }
    if (s.startsWith(r'$') && s.endsWith(r'$') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith(r'\(') && s.endsWith(r'\)') && s.length > 4) {
      s = s.substring(2, s.length - 2).trim();
    }
    if (s.startsWith(r'\[') && s.endsWith(r'\]') && s.length > 4) {
      s = s.substring(2, s.length - 2).trim();
    }
    return s.replaceAll(r'$', '').trim();
  }

  /// Alternate bodies to try when the first TeX parse fails.
  static List<String> texCandidates(String tex) {
    final seen = <String>{};
    final out = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isEmpty || !seen.add(t)) return;
      out.add(t);
    }

    add(stackedTex(tex));
    add(sanitizeTex(tex));
    final stacked = stackedTex(tex);
    add(stacked.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '\\frac{${m[1]!.trim()}}{${m[2]!.trim()}}',
    ));
    add(stacked.replaceAll('=', ' = '));
    add(stacked.replaceAllMapped(RegExp(r'\^\{([^{}]+)\}'), (m) => '^${m[1]}'));
    return out;
  }

  static bool containsTex(String s) =>
      RegExp(r'\\[a-zA-Z]+').hasMatch(s) ||
      s.contains(r'\frac') ||
      (s.contains(r'$') && RegExp(r'[=^_{}]').hasMatch(s));

  /// Last-resort readable line — never dump `$` or `\frac` source.
  static String prettyFallback(String tex) {
    var s = sanitizeTex(tex);
    s = s.replaceAll(r'\times', '×');
    s = s.replaceAll(r'\cdot', '·');
    s = s.replaceAll(r'\div', '÷');
    s = s.replaceAll(r'\pm', '±');
    s = s.replaceAll(r'\pi', 'π');
    s = s.replaceAll(r'\neq', '≠');
    s = s.replaceAll(r'\le', '≤');
    s = s.replaceAll(r'\leq', '≤');
    s = s.replaceAll(r'\ge', '≥');
    s = s.replaceAll(r'\geq', '≥');
    s = s.replaceAll(r'\approx', '≈');
    s = s.replaceAll(r'\infty', '∞');
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) {
        final a = m[1]!.trim();
        final b = m[2]!.trim();
        if (a == '1' && b == '2') return '½';
        if (a == '1' && b == '4') return '¼';
        if (a == '3' && b == '4') return '¾';
        return '$a/$b';
      },
    );
    s = s.replaceAllMapped(RegExp(r'\^\{([^{}]+)\}'), (m) {
      return m[1]!.split('').map((c) => _superOut[c] ?? c).join();
    });
    s = s.replaceAllMapped(RegExp(r'\^([A-Za-z0-9])'), (m) {
      return _superOut[m[1]!] ?? m[1]!;
    });
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ');
    s = s.replaceAll(RegExp(r'[{}\\$]+'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
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
      // `\$` is a delimiter (models escape dollars), not a literal `$`.
      if (raw[i] == r'\' && i + 1 < n && raw[i + 1] == r'$') {
        i += 1;
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

  static String _mapOutsideMath(String raw, String Function(String prose) fn) {
    final buf = StringBuffer();
    for (final span in scan(raw)) {
      if (span.isMath) {
        buf.write(span.raw);
      } else {
        buf.write(fn(span.prose));
      }
    }
    return buf.toString();
  }

  static String _stripMarkdown(String prose) {
    var s = prose;
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!);
    s = s.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1]!);
    s = s.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1]!);
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
    s = s.replaceAllMapped(RegExp(r'^#{1,6}\s+', multiLine: true), (_) => '');
    return s;
  }

  static const _superOut = {
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '0': '⁰',
  };

  static const _superMap = {
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '⁰': '0',
  };

  static const _subMap = {
    '₀': '0',
    '₁': '1',
    '₂': '2',
    '₃': '3',
    '₄': '4',
    '₅': '5',
    '₆': '6',
    '₇': '7',
    '₈': '8',
    '₉': '9',
  };

  static const _greekMap = {
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'δ': r'\delta',
    'Δ': r'\Delta',
    'θ': r'\theta',
    'λ': r'\lambda',
    'μ': r'\mu',
    'π': r'\pi',
    'σ': r'\sigma',
    'ω': r'\omega',
    'Σ': r'\Sigma',
    'Ω': r'\Omega',
  };

  /// Turns common Unicode fake-math in prose into `$...$` so it can render.
  static String _unicodeMathHints(String prose) {
    var s = prose;
    s = s.replaceAllMapped(RegExp(r'([A-Za-z0-9πθαλΔ\)\]])([²³¹⁰⁴⁵⁶⁷⁸⁹]+)'), (
      m,
    ) {
      final exp = m[2]!.split('').map((c) => _superMap[c] ?? c).join();
      return '\$${m[1]}^{$exp}\$';
    });
    s = s.replaceAllMapped(RegExp(r'([A-Za-z])([₀-₉]+)'), (m) {
      final sub = m[2]!.split('').map((c) => _subMap[c] ?? c).join();
      return '\$${m[1]}_{$sub}\$';
    });
    s = s.replaceAllMapped(RegExp(r'√\s*\(([^()\n]{1,48})\)'), (m) {
      return '\$\\sqrt{${m[1]!.trim()}}\$';
    });
    s = s.replaceAllMapped(RegExp(r'√\s*([A-Za-z0-9]+)'), (m) {
      return '\$\\sqrt{${m[1]}}\$';
    });
    s = s.replaceAll('½', r'$\frac{1}{2}$');
    s = s.replaceAll('¼', r'$\frac{1}{4}$');
    s = s.replaceAll('¾', r'$\frac{3}{4}$');
    s = s.replaceAll('×', r'$\times$');
    s = s.replaceAll('÷', r'$\div$');
    s = s.replaceAll('±', r'$\pm$');
    s = s.replaceAll('≠', r'$\neq$');
    s = s.replaceAll('≤', r'$\le$');
    s = s.replaceAll('≥', r'$\ge$');
    s = s.replaceAll('≈', r'$\approx$');
    s = s.replaceAll('∞', r'$\infty$');
    s = s.replaceAllMapped(
      RegExp(r'(?<![A-Za-z\\$])([αβγδΔθλμπσωΣΩ])(?![A-Za-z])'),
      (m) => '\$${_greekMap[m[1]!]}\$',
    );
    return s;
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
      RegExp(r'(?<![\$])\\+frac\s*\{[^{}]+\}\s*\{[^{}]+\}'),
      (m) {
        final body = m[0]!.replaceAllMapped(
          RegExp(r'\\+frac'),
          (_) => r'\frac',
        );
        return '\$$body\$';
      },
    );
    return s;
  }

  static String _promoteTexChunks(String prose) {
    if (!prose.contains(r'\frac') &&
        !prose.contains(r'\sqrt') &&
        !prose.contains(r'\dfrac')) {
      return prose;
    }
    return prose.replaceAllMapped(
      RegExp(
        r'(?:[A-Za-z][A-Za-z0-9]{0,11}\s*=\s*)?'
        r'\$*\\+(?:frac|dfrac|tfrac|sqrt)(?:\s*\{[^{}]*\}\s*){1,2}\$*'
        r'(?:[A-Za-z0-9]+(?:\^\{?[0-9]+\}?)?)*',
      ),
      (m) {
        final chunk = m[0]!.replaceAll('\$', '').trim();
        if (chunk.isEmpty) return m[0]!;
        return '\$$chunk\$';
      },
    );
  }

  static String _closeUnpairedDollars(String s) {
    return s.split('\n').map((line) {
      if (line.contains(r'$$')) return line;
      final n = RegExp(r'\$').allMatches(line).length;
      if (n == 1) return '$line\$';
      return line;
    }).join('\n');
  }

  static String _repairDecodedTex(String s) {
    return s
        .replaceAll('\u000crac', r'\frac')
        .replaceAll('\u0008eta', r'\beta')
        .replaceAll('\u0008egin', r'\begin')
        .replaceAll('\u0009imes', r'\times')
        .replaceAll('\u0009heta', r'\theta')
        .replaceAll('\u0009ext', r'\text');
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

const latexMathInstructions = r'''
Any formula must be real LaTeX inside $...$ (inline) or $$...$$ (block).
Never Unicode fake math (x², ½, π as a symbol) and never plain x^2 / a/b when a formula is needed.
Fractions must be stacked as $\frac{numerator}{denominator}$.
Do not wrap formulas in markdown (**bold**, `code`). Do not use \(...\) or \[...\] — use $...$ / $$...$$.
''';

const mathAndConceptInstructions = '''
Write conceptually in words first: what the idea means, why it matters, and when you would use it.
Never leave a topic as bare letters or a lone formula (not "F=ma", not "a/b", not "x").
$latexMathInstructions
Name each symbol in words beside the formula.
''';

const quizletRevisionInstructions = '''
Write Quizlet-style retrieval items: short, specific, one fact each.
Prompt/front: a term, "What is X?", "Define …", "Solve: …", true/false stem, or a one-line MCQ. Not an essay.
Answer/back: one term, one number, one formula, or one short sentence. No multi-paragraph explanations.
Do not ask the student to "explain in detail", "discuss", or "in your own words at length" unless they asked for essays.
Match the difficulty of the lecture/notes. Do not invent harder theory.
$latexMathInstructions
''';
