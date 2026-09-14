import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_organiser/services/subscription_catalog.dart';
import 'package:flutter_organiser/ui/shell_nav.dart';

void main() {
  group('Free vs Pro chrome', () {
    test('Home, Plan, and Subjects stay free', () {
      expect(pageRequiresPro(AppPage.dashboard), isFalse);
      expect(pageRequiresPro(AppPage.studyTime), isFalse);
      expect(pageRequiresPro(AppPage.notes), isFalse);
      expect(pageRequiresPro(AppPage.planner), isFalse);
      expect(pageRequiresPro(AppPage.calendar), isFalse);
      expect(pageRequiresPro(AppPage.weeklyPlanner), isFalse);
      expect(pageRequiresPro(AppPage.assessments), isFalse);
      expect(pageRequiresPro(AppPage.subjects), isFalse);
      expect(pageRequiresPro(AppPage.settings), isFalse);
      expect(pageRequiresPro(AppPage.profile), isFalse);
    });

    test('Study destinations require Pro', () {
      expect(pageRequiresPro(AppPage.lectureLab), isTrue);
      expect(pageRequiresPro(AppPage.consolidation), isTrue);
      expect(pageRequiresPro(AppPage.voiceChat), isTrue);
      expect(pageRequiresPro(AppPage.studyRoulette), isTrue);
      expect(pageRequiresPro(AppPage.pomodoro), isTrue);
      expect(sectionRequiresPro(ShellSection.study), isTrue);
      expect(sectionRequiresPro(ShellSection.home), isFalse);
      expect(sectionRequiresPro(ShellSection.plan), isFalse);
      expect(sectionRequiresPro(ShellSection.courses), isFalse);
    });
  });

  group('EntitlementPolicy', () {
    test('release mobile needs a store purchase', () {
      expect(
        EntitlementPolicy.isPro(
          debugMode: false,
          forceFree: false,
          unlockDefine: false,
          isWindows: false,
          isLinux: false,
          storePro: false,
        ),
        isFalse,
      );
      expect(
        EntitlementPolicy.isPro(
          debugMode: false,
          forceFree: false,
          unlockDefine: false,
          isWindows: false,
          isLinux: false,
          storePro: true,
        ),
        isTrue,
      );
    });

    test('debug and Windows are Pro unless Force Free', () {
      expect(
        EntitlementPolicy.isPro(
          debugMode: true,
          forceFree: false,
          unlockDefine: false,
          isWindows: false,
          isLinux: false,
          storePro: false,
        ),
        isTrue,
      );
      expect(
        EntitlementPolicy.isPro(
          debugMode: true,
          forceFree: true,
          unlockDefine: false,
          isWindows: false,
          isLinux: false,
          storePro: true,
        ),
        isFalse,
      );
      expect(
        EntitlementPolicy.isPro(
          debugMode: false,
          forceFree: false,
          unlockDefine: false,
          isWindows: true,
          isLinux: false,
          storePro: false,
        ),
        isTrue,
      );
    });

    test('dart-define unlocks Pro without a public toggle', () {
      expect(
        EntitlementPolicy.isPro(
          debugMode: false,
          forceFree: false,
          unlockDefine: true,
          isWindows: false,
          isLinux: false,
          storePro: false,
        ),
        isTrue,
      );
    });

    test('store IAP is required on release iOS Android macOS', () {
      expect(
        EntitlementPolicy.storeEnforcesIap(
          debugMode: false,
          isIOS: true,
          isAndroid: false,
          isMacOS: false,
        ),
        isTrue,
      );
      expect(
        EntitlementPolicy.storeEnforcesIap(
          debugMode: true,
          isIOS: true,
          isAndroid: false,
          isMacOS: false,
        ),
        isFalse,
      );
    });
  });

  group('AI allowance reset', () {
    test('calendar month key and remaining uses', () {
      expect(AiAllowanceLogic.monthKey(DateTime(2026, 9, 14)), '2026-09');
      expect(AiAllowanceLogic.remaining(0), SubscriptionCatalog.monthlyAiUses);
      expect(AiAllowanceLogic.remaining(12), 28);
      expect(AiAllowanceLogic.canConsume(39), isTrue);
      expect(AiAllowanceLogic.canConsume(40), isFalse);
      expect(AiAllowanceLogic.canConsume(39, 2), isFalse);
    });

    test('rolls used count to zero on a new calendar month', () {
      final same = AiAllowanceLogic.applyReset(
        storedMonth: '2026-09',
        storedUsed: 18,
        now: DateTime(2026, 9, 30),
      );
      expect(same.monthKey, '2026-09');
      expect(same.used, 18);

      final next = AiAllowanceLogic.applyReset(
        storedMonth: '2026-09',
        storedUsed: 40,
        now: DateTime(2026, 10, 1),
      );
      expect(next.monthKey, '2026-10');
      expect(next.used, 0);
      expect(AiAllowanceLogic.nextReset(DateTime(2026, 9, 14)), DateTime(2026, 10, 1));
    });

    test('catalog prices and SKUs', () {
      expect(SubscriptionCatalog.monthlyProductId, 'pro_monthly');
      expect(SubscriptionCatalog.annualProductId, 'pro_annual');
      expect(SubscriptionCatalog.monthlyListPriceUsd, 4.99);
      expect(SubscriptionCatalog.annualListPriceUsd, 39.99);
      expect(SubscriptionCatalog.monthlyAiUses, 40);
    });
  });
}
