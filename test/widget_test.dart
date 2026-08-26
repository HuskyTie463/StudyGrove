import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test — app shell not loaded (needs Firebase in integration tests)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Nook tests OK')),
        ),
      ),
    );
    expect(find.text('Nook tests OK'), findsOneWidget);
  });
}
