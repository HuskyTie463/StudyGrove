import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_organiser/config/background_assets.dart';
import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/ui/add_task_dialog.dart';
import 'package:flutter_organiser/ui/shared_ui.dart';

void main() {
  testWidgets('GroveWallpaper covers from the bottom so sides stay filled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GroveWallpaper(asset: kDefaultBackgroundAsset),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(GroveWallpaper.fit, BoxFit.cover);
    expect(image.alignment, Alignment.bottomCenter);
    expect(GroveWallpaper.anchor, Alignment.bottomCenter);
    expect(image.fit, isNot(BoxFit.contain));
  });

  test('custom wallpaper paths are local files, not bundled scenes', () {
    expect(isBundledBackgroundAsset(kDefaultBackgroundAsset), isTrue);
    expect(isCustomWallpaperPath(kDefaultBackgroundAsset), isFalse);
    expect(isCustomWallpaperPath('assets/backgrounds/bg_01.png'), isFalse);
    expect(isCustomWallpaperPath(kCustomWallpaperRemoteMarker), isFalse);
    expect(
      isCustomWallpaperPath(r'C:\Users\me\wallpapers\custom_1.jpg'),
      isTrue,
    );
  });

  testWidgets('Enter submits a trimmed to-do from the composer', (tester) async {
    (String, TaskUrgency)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<(String, TaskUrgency)?>(
                context: context,
                builder: (_) => const AddTaskDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Read chapter 3  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result?.$1, 'Read chapter 3');
    expect(result?.$2, TaskUrgency.normal);
  });

  testWidgets('physical Enter submits a to-do on desktop', (tester) async {
    (String, TaskUrgency)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<(String, TaskUrgency)?>(
                context: context,
                builder: (_) => const AddTaskDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Practice quiz');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result?.$1, 'Practice quiz');
  });

  testWidgets('Enter does not submit whitespace-only to-dos', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<(String, TaskUrgency)?>(
                context: context,
                builder: (_) => const AddTaskDialog(),
              );
              if (result != null) submitted = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(find.byType(AddTaskDialog), findsOneWidget);
  });
}
