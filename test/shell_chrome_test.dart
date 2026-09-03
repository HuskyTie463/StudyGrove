import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_organiser/ui/shell_nav.dart';

void main() {
  testWidgets('phone width uses compact chrome, not the desktop rail',
      (tester) async {
    late bool phone;
    late bool tablet;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              phone = useDesktopChrome(context);
              return MediaQuery(
                data: const MediaQueryData(size: Size(1024, 768)),
                child: Builder(
                  builder: (context) {
                    tablet = useDesktopChrome(context);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(phone, isFalse);
    expect(tablet, isTrue);
  });

  test('every rail page has a title', () {
    for (final def in kShellSections) {
      for (final child in def.children) {
        expect(titleForPage(child.page), isNotEmpty);
      }
    }
    expect(titleForPage(AppPage.settings), 'Settings');
    expect(titleForPage(AppPage.profile), 'Profile');
    expect(titleForPage(AppPage.backgrounds), 'Backgrounds');
  });

  test('timetable copy link is an in-app deep link', () {
    expect(kTimetableAccessLink, 'studygrove://timetable');
  });
}
