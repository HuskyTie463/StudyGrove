import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/pages/study_time_page.dart';
import 'package:flutter_organiser/theme/style_family.dart';
import 'package:flutter_organiser/theme/token_packs.dart';
import 'package:flutter_organiser/utils/datetime_utils.dart';

void main() {
  final maths = Subject(
    id: 'maths',
    name: 'Maths',
    colorValue: 0xFF6FA98A,
  );
  final piano = Subject(
    id: 'piano',
    name: 'Piano',
    colorValue: 0xFFE8B4A0,
    kind: SubjectKind.hobby,
  );

  testWidgets('Add time dialog logs hours and minutes for a subject',
      (tester) async {
    (String, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<(String, int)?>(
                context: context,
                builder: (_) => AddManualTimeDialog(
                  subjects: [maths],
                  initialSubjectId: maths.id,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual_hours')), '1');
    await tester.enterText(find.byKey(const Key('manual_minutes')), '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(result?.$1, 'maths');
    expect(result?.$2, 75);
  });

  testWidgets('Add time dialog asks for a subject when none is picked',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showDialog<(String, int)?>(
                context: context,
                builder: (_) => AddManualTimeDialog(
                  subjects: [maths, piano],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('Pick a subject for this time.'), findsOneWidget);
    expect(find.byType(AddManualTimeDialog), findsOneWidget);
  });

  testWidgets(
      'Add time can log one subject without a chrome subject selected',
      (tester) async {
    (String, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<(String, int)?>(
                context: context,
                builder: (_) => AddManualTimeDialog(
                  subjects: [maths, piano],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maths').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(result?.$1, 'maths');
    expect(result?.$2, 30);
  });

  ThemeData _tokensTheme() {
    return ThemeData(
      extensions: [
        TokenPackRegistry.resolve(
          family: VisualStyleFamily.signature,
          dark: false,
          spacing: SpacingDensity.comfortable,
          contrast: ContrastLevel.normal,
          reducedMotion: true,
        ),
      ],
    );
  }

  testWidgets('Remove time dialog subtracts minutes from a listed subject',
      (tester) async {
    TimeRemoval? result;
    final today = dayKey(DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        theme: _tokensTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<TimeRemoval?>(
                context: context,
                builder: (_) => RemoveTimeDialog(
                  subjects: [maths],
                  initialSubjectId: maths.id,
                  totals: [
                    StudyDayTotal(
                      subjectId: maths.id,
                      dayKey: today,
                      minutes: 90,
                    ),
                  ],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Logged recently'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('remove_hours')), '0');
    await tester.enterText(find.byKey(const Key('remove_minutes')), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(result?.subjectId, 'maths');
    expect(result?.minutes, 20);
  });

  testWidgets('Remove time can target one subject while All subjects is shown',
      (tester) async {
    TimeRemoval? result;
    final today = dayKey(DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        theme: _tokensTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<TimeRemoval?>(
                context: context,
                builder: (_) => RemoveTimeDialog(
                  subjects: [maths, piano],
                  totals: [
                    StudyDayTotal(
                      subjectId: maths.id,
                      dayKey: today,
                      minutes: 45,
                    ),
                  ],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maths').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(result?.subjectId, 'maths');
    expect(result?.minutes, 15);
  });

  testWidgets('Goal dialog sets hours and minutes for one subject',
      (tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('All subjects')),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<int>(
                  context: context,
                  builder: (_) => EditWeekGoalDialog(
                    subject: maths,
                    initialMinutes: 10 * 60,
                  ),
                );
              },
              child: const Text('Goal'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('All subjects'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal_hours')), '4');
    await tester.enterText(find.byKey(const Key('goal_minutes')), '30');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(result, 270);
    expect(find.text('All subjects'), findsOneWidget);
  });

  testWidgets('Goal dialog can target a hobby without a subject dropdown',
      (tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<int>(
                context: context,
                builder: (_) => EditWeekGoalDialog(
                  subject: piano,
                  initialMinutes: 60,
                ),
              );
            },
            child: const Text('Goal'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly goal'), findsOneWidget);
    expect(find.textContaining('Piano'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.enterText(find.byKey(const Key('goal_hours')), '1');
    await tester.enterText(find.byKey(const Key('goal_minutes')), '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(result, 75);
  });
}
