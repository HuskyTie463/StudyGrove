import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../services/math_format.dart';

/// Mixed prose + LaTeX, rendered in document order (inline and block).
class MathText extends StatelessWidget {
  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.color,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final prepared = MathFormat.forDisplay(text);
    final inherited = DefaultTextStyle.of(context).style;
    final base = (style ?? inherited).copyWith(
      color: color ?? style?.color ?? inherited.color,
      height: style?.height ?? 1.45,
    );
    final pieces = MathFormat.scan(prepared);
    if (pieces.isEmpty) {
      return _plainOrTex(text, base);
    }
    if (pieces.length == 1 && !pieces.first.isMath) {
      return _plainOrTex(pieces.first.prose, base);
    }
    if (pieces.length == 1 && pieces.first.isDisplay) {
      return _tex(pieces.first.tex!, base, display: true);
    }

    final rows = <Widget>[];
    final inline = <InlineSpan>[];

    void flushInline() {
      if (inline.isEmpty) return;
      rows.add(
        Text.rich(
          TextSpan(style: base, children: List<InlineSpan>.of(inline)),
          textAlign: textAlign,
        ),
      );
      inline.clear();
    }

    for (final piece in pieces) {
      if (!piece.isMath) {
        if (piece.prose.isEmpty) continue;
        if (MathFormat.containsTex(piece.prose)) {
          inline.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _tex(piece.prose, base, display: false),
            ),
          );
        } else {
          inline.add(TextSpan(text: piece.prose, style: base));
        }
        continue;
      }
      if (!piece.isDisplay) {
        inline.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _tex(piece.tex!, base, display: false),
          ),
        );
        continue;
      }
      flushInline();
      rows.add(_tex(piece.tex!, base, display: true));
    }
    flushInline();

    if (rows.length == 1) return rows.first;
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _plainOrTex(String raw, TextStyle base) {
    if (MathFormat.containsTex(raw)) {
      return _tex(raw, base, display: false);
    }
    return Text(raw, style: base, textAlign: textAlign);
  }

  Widget _tex(String tex, TextStyle style, {required bool display}) {
    final fontSize = style.fontSize ?? 16;
    final color = style.color ?? const Color(0xFF1A1A1A);
    final options = MathOptions(
      style: display ? MathStyle.display : MathStyle.text,
      fontSize: fontSize,
      color: color,
    );
    const settings = TexParserSettings(strict: Strict.ignore);
    final mathStyle = display ? MathStyle.display : MathStyle.text;

    Math? parsed;
    for (final candidate in MathFormat.texCandidates(tex)) {
      final attempt = Math.tex(
        candidate,
        mathStyle: mathStyle,
        options: options,
        settings: settings,
        onErrorFallback: (_) => const SizedBox.shrink(),
      );
      if (attempt.parseError == null) {
        parsed = attempt;
        break;
      }
    }

    final math = parsed ??
        Math.tex(
          MathFormat.stackedTex(tex),
          mathStyle: mathStyle,
          options: options,
          settings: settings,
          onErrorFallback: (_) => Text(
            MathFormat.prettyFallback(tex),
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
        );

    if (!display) return math;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}
