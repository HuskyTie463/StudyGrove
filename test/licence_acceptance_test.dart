import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_organiser/legal/beta_licence.dart';
import 'package:flutter_organiser/pages/licence_agreement_page.dart';
import 'package:flutter_organiser/pages/licence_gate.dart';
import 'package:flutter_organiser/services/licence_acceptance_service.dart';

LicenceAcceptanceService testService({
  MemoryLicenceStore? local,
  Map<String, MemoryLicenceStore>? clouds,
  String requiredVersion = '1.0',
}) {
  final cloudMap = clouds ?? <String, MemoryLicenceStore>{};
  return LicenceAcceptanceService(
    localStore: local ?? MemoryLicenceStore(),
    cloudStoreFor: (uid) =>
        cloudMap.putIfAbsent(uid, MemoryLicenceStore.new),
    appVersionReader: () async => '1.0.6+6',
    clock: () => DateTime.utc(2026, 9, 14, 10, 0, 0),
    requiredVersion: requiredVersion,
  );
}

Widget wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('canonical 1.0 body is stored verbatim', () {
    expect(BetaLicence.currentVersion, '1.0');
    expect(BetaLicence.currentText, BetaLicence.bodyV1_0);
    expect(
      BetaLicence.currentText,
      contains('Study Grove — Beta Software Licence Agreement'),
    );
    expect(BetaLicence.currentText, contains('Publisher: Adara Curry'));
    expect(BetaLicence.currentText, contains('Effective date: 14/09/2026'));
    expect(
      BetaLicence.currentText,
      contains('You can review this agreement again in the app’s settings.'),
    );
  });

  group('LicenceAcceptanceService', () {
    test('decline path never writes a record', () async {
      final local = MemoryLicenceStore();
      final service = testService(local: local);
      expect(await service.needsAcceptance(), isTrue);
      expect(local.records, isEmpty);
    });

    test('successful save is required before acceptance counts', () async {
      final local = MemoryLicenceStore(failNextAppend: true);
      final service = testService(local: local);
      expect(
        () => service.accept(),
        throwsA(isA<LicenceSaveException>()),
      );
      expect(local.records, isEmpty);
      expect(await service.needsAcceptance(), isTrue);

      await service.accept();
      expect(local.records, hasLength(1));
      expect(await service.needsAcceptance(), isFalse);
      expect(local.records.single.version, '1.0');
      expect(local.records.single.agreementText, BetaLicence.bodyV1_0);
      expect(local.records.single.appVersion, '1.0.6+6');
    });

    test('version bump re-prompts and previous records are preserved', () async {
      final local = MemoryLicenceStore();
      final clouds = <String, MemoryLicenceStore>{};
      final v1 = testService(local: local, clouds: clouds);
      await v1.accept(uid: 'user-1');
      expect(await v1.needsAcceptance(uid: 'user-1'), isFalse);
      expect(clouds['user-1']!.records, hasLength(1));

      final v2 = testService(
        local: local,
        clouds: clouds,
        requiredVersion: '1.1',
      );
      expect(await v2.needsAcceptance(uid: 'user-1'), isTrue);

      await v2.accept(uid: 'user-1');
      expect(await v2.needsAcceptance(uid: 'user-1'), isFalse);
      expect(clouds['user-1']!.records, hasLength(2));
      expect(
        clouds['user-1']!.records.map((r) => r.version).toList(),
        ['1.0', '1.1'],
      );
    });

    test('guest accept migrates to the account without a second prompt',
        () async {
      final local = MemoryLicenceStore();
      final clouds = <String, MemoryLicenceStore>{};
      final service = testService(local: local, clouds: clouds);
      await service.accept();
      expect(await service.needsAcceptance(), isFalse);
      expect(clouds, isEmpty);

      expect(await service.needsAcceptance(uid: 'user-2'), isFalse);
      expect(clouds['user-2']!.records, hasLength(1));
      expect(clouds['user-2']!.records.single.accountId, 'user-2');
      expect(clouds['user-2']!.records.single.version, '1.0');
    });

    test('existing signed-in user with no record must be asked', () async {
      final local = MemoryLicenceStore();
      final clouds = <String, MemoryLicenceStore>{
        'legacy-user': MemoryLicenceStore(),
      };
      final service = testService(local: local, clouds: clouds);
      expect(await service.needsAcceptance(uid: 'legacy-user'), isTrue);
      expect(clouds['legacy-user']!.records, isEmpty);
      expect(local.records, isEmpty);
    });

    test('cloud current version skips the dialog', () async {
      final clouds = <String, MemoryLicenceStore>{
        'user-3': MemoryLicenceStore(),
      };
      final service = testService(clouds: clouds);
      await clouds['user-3']!.append(
        LicenceAcceptanceRecord(
          accountId: 'user-3',
          version: '1.0',
          acceptedAt: DateTime.utc(2026, 9, 14),
          appVersion: '1.0.6+6',
          agreementText: BetaLicence.bodyV1_0,
        ),
      );
      expect(await service.needsAcceptance(uid: 'user-3'), isFalse);
    });
  });

  group('LicenceAgreementPage', () {
    testWidgets('checkbox gates the agree button', (tester) async {
      await tester.pumpWidget(
        wrap(const LicenceAgreementPage(onDecline: _noop)),
      );
      await tester.pumpAndSettle();

      final agree = find.widgetWithText(
        FilledButton,
        BetaLicence.agreeButtonLabel,
      );
      expect(tester.widget<FilledButton>(agree).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(tester.widget<FilledButton>(agree).onPressed, isNotNull);
    });

    testWidgets('decline does not persist', (tester) async {
      final local = MemoryLicenceStore();
      final service = testService(local: local);
      var declined = false;

      await tester.pumpWidget(
        wrap(
          LicenceAgreementPage(
            service: service,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, BetaLicence.declineButtonLabel),
      );
      await tester.pump();

      expect(declined, isTrue);
      expect(local.records, isEmpty);
      expect(await service.needsAcceptance(), isTrue);
    });

    testWidgets('failed save stays on the dialog and shows an error',
        (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        wrap(
          LicenceAgreementPage(
            onDecline: _noop,
            onAccept: () async {
              attempts++;
              throw LicenceSaveException();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, BetaLicence.agreeButtonLabel),
      );
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text(LicenceSaveException.saveFailedMessage), findsOneWidget);
      expect(find.text(BetaLicence.agreeButtonLabel), findsOneWidget);
      expect(find.byType(LicenceAgreementPage), findsOneWidget);
    });

    testWidgets('successful save is required before the gate continues',
        (tester) async {
      final local = MemoryLicenceStore();
      final service = testService(local: local);
      var accepted = false;

      await tester.pumpWidget(
        wrap(
          LicenceGate(
            service: service,
            child: const Scaffold(body: Text('Main app')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Main app'), findsNothing);
      expect(find.byType(LicenceAgreementPage), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, BetaLicence.agreeButtonLabel),
      );
      await tester.pumpAndSettle();

      accepted = !await service.needsAcceptance();
      expect(accepted, isTrue);
      expect(local.records, hasLength(1));
      expect(find.text('Main app'), findsOneWidget);
    });
  });
}

void _noop() {}
