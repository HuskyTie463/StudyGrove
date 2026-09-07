import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_organiser/services/math_format.dart';
import 'package:flutter_organiser/ui/math_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ke = r'Energy of motion: $KE = \frac{1}{2}mv^{2}$';

  test('scan extracts the kinetic energy formula as math', () {
    final pieces = MathFormat.scan(MathFormat.forDisplay(ke));
    expect(pieces.where((p) => p.isMath), isNotEmpty);
    final tex = pieces.firstWhere((p) => p.isMath).tex!;
    expect(tex, contains(r'\frac'));
    expect(tex.contains(r'$'), isFalse);
    expect(MathFormat.sanitizeTex(tex), r'KE = \frac{1}{2}mv^{2}');
  });

  test('unpaired and escaped dollars still become math', () {
    for (final raw in [
      r'Energy of motion: $KE = \frac{1}{2}mv^{2}',
      r'Energy of motion: \$KE = \frac{1}{2}mv^{2}\$',
      r'Energy of motion: KE = \frac{1}{2}mv^{2}',
      'Energy of motion: \$KE = \\frac{1}{2}mv^{2}\$',
    ]) {
      final pieces = MathFormat.scan(MathFormat.forDisplay(raw));
      expect(
        pieces.any((p) => p.isMath && p.tex!.contains(r'\frac')),
        isTrue,
        reason: raw,
      );
    }
  });

  test('double-escaped frac collapses to one backslash', () {
    final raw = r'$KE = \\frac{1}{2}mv^{2}$';
    expect(MathFormat.stackedTex(MathFormat.normalizeRevisionText(raw)),
        r'KE = \frac{1}{2}mv^{2}');
  });

  test('repairModelJson saves \\frac from being eaten as form feed', () {
    final raw = r'{"back":"Energy of motion: $KE = \frac{1}{2}mv^{2}$"}';
    final eaten = jsonDecode(raw) as Map<String, dynamic>;
    expect(eaten['back'], contains('\u000c'));

    final map =
        jsonDecode(MathFormat.repairModelJson(raw)) as Map<String, dynamic>;
    expect(map['back'], contains(r'\frac'));
    expect(map['back'], isNot(contains('\u000c')));
  });

  test('prettyFallback never dumps dollar or frac source', () {
    final pretty = MathFormat.prettyFallback(r'KE = \frac{1}{2}mv^{2}');
    expect(pretty, isNot(contains(r'\frac')));
    expect(pretty, isNot(contains(r'$')));
    expect(pretty, contains('½'));
  });

  test('flutter_math_fork parses sanitized KE formula', () {
    for (final candidate in MathFormat.texCandidates(r'KE = \frac{1}{2}mv^{2}')) {
      final math = Math.tex(candidate);
      expect(math.parseError, isNull, reason: candidate);
    }
  });

  testWidgets('MathText shows TeX widget, not source', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MathText(ke),
        ),
      ),
    );
    expect(find.textContaining(r'\frac'), findsNothing);
    expect(find.textContaining(r'$KE'), findsNothing);
    expect(find.byType(Math), findsWidgets);
    final math = tester.widget<Math>(find.byType(Math).first);
    expect(math.parseError, isNull);
  });
}
