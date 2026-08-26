import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../services/math_format.dart';

/// Mixed prose + stacked math (fractions as numerator over denominator).
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

  static final _block = RegExp(
    r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\$([^$\n]+?)\$|\\\((.+?)\\\)',
  );

  @override
  Widget build(BuildContext context) {
    final prepared = MathFormat.forDisplay(text);
    final inherited = DefaultTextStyle.of(context).style;
    final base = (style ?? inherited).copyWith(
      color: color ?? style?.color,
      height: style?.height ?? 1.45,
      fontFamily: style?.fontFamily ?? inherited.fontFamily,
    );
    final pieces = _parse(prepared);
    if (pieces.isEmpty) {
      return Text(text, style: base, textAlign: textAlign);
    }
    if (pieces.length == 1 && pieces.first.isDisplay) {
      return _tex(pieces.first.tex!, base, display: true);
    }

    final spans = <InlineSpan>[];
    final extras = <Widget>[];
    for (final piece in pieces) {
      if (piece.tex == null) {
        if (piece.prose.isEmpty) continue;
        spans.add(TextSpan(text: piece.prose, style: base));
        continue;
      }
      if (piece.isDisplay) {
        extras.add(_tex(piece.tex!, base, display: true));
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _tex(piece.tex!, base, display: false),
        ),
      );
    }

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(style: base, children: spans),
          textAlign: textAlign,
        ),
        ...extras,
      ],
    );
  }

  Widget _tex(String tex, TextStyle style, {required bool display}) {
    final stacked = MathFormat.stackedTex(tex);
    return Math.tex(
      stacked,
      textStyle: style,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      onErrorFallback: (_) => Text(tex, style: style),
    );
  }

  List<_Piece> _parse(String raw) {
    final out = <_Piece>[];
    var cursor = 0;
    for (final match in _block.allMatches(raw)) {
      if (match.start > cursor) {
        out.add(_Piece.prose(raw.substring(cursor, match.start)));
      }
      final display = match[1] != null || match[2] != null;
      final tex = (match[1] ?? match[2] ?? match[3] ?? match[4] ?? '').trim();
      if (tex.isNotEmpty) {
        out.add(_Piece.math(tex, display: display));
      }
      cursor = match.end;
    }
    if (cursor < raw.length) {
      out.add(_Piece.prose(raw.substring(cursor)));
    }
    return out;
  }
}

class _Piece {
  const _Piece._(this.prose, this.tex, this.isDisplay);
  factory _Piece.prose(String s) => _Piece._(s, null, false);
  factory _Piece.math(String tex, {required bool display}) =>
      _Piece._('', tex, display);

  final String prose;
  final String? tex;
  final bool isDisplay;
}
