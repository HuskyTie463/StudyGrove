import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/pages/study_time_page.dart';

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
}
