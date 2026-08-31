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
      color: color ?? style?.color,
      height: style?.height ?? 1.45,
      fontFamily: style?.fontFamily ?? inherited.fontFamily,
    );
    final pieces = MathFormat.scan(prepared);
    if (pieces.isEmpty) {
      return Text(text, style: base, textAlign: textAlign);
    }
    if (pieces.length == 1 && !pieces.first.isMath) {
      return Text(pieces.first.prose, style: base, textAlign: textAlign);
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
        inline.add(TextSpan(text: piece.prose, style: base));
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

  Widget _tex(String tex, TextStyle style, {required bool display}) {
    final stacked = MathFormat.stackedTex(tex);
    final math = Math.tex(
      stacked,
      textStyle: style,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      onErrorFallback: (_) => Text(
        MathFormat.forSpeech('\$$tex\$'),
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
