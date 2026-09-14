/// Store SKUs for Study Grove Pro.
///
/// Create these exact products today:
///
/// **App Store Connect** (Subscriptions, bundle `com.adaracurry.studygrove`)
/// — `pro_monthly`: Auto-Renewable, 1 month, USD 4.99
/// — `pro_annual`: Auto-Renewable, 1 year, USD 39.99 (~33% off vs 12×4.99)
/// Enable In-App Purchase on the App ID for iOS and macOS.
///
/// **Google Play Console** (Subscriptions, package `com.adaracurry.studygrove`)
/// — Subscription product `pro_monthly` with a monthly base plan, USD 4.99
/// — Subscription product `pro_annual` with a yearly base plan, USD 39.99
/// Billing permission is merged from `in_app_purchase`.
///
/// Windows has no Play/App Store IAP. Release Windows stays Pro for the
/// owner's daily driver. Production iOS / Android / macOS enforce the store.
class SubscriptionCatalog {
  static const monthlyProductId = 'pro_monthly';
  static const annualProductId = 'pro_annual';

  static const monthlyListPriceUsd = 4.99;
  static const annualListPriceUsd = 39.99;

  static const monthlyLabel = r'$4.99/month';
  static const annualLabel = r'$39.99/year';
  static const annualSavingsLabel = '33% off vs paying monthly';

  /// Calendar-month Study AI uses included with Pro (monthly or annual).
  static const monthlyAiUses = 40;

  /// Extra Voice Chat use charged after this many minutes in one session.
  static const voiceExtraUseMinutes = 8;

  static const productIds = <String>{
    monthlyProductId,
    annualProductId,
  };

  static String get allowanceLine =>
      '$monthlyAiUses Study AI uses / month';

  static String get annualVsMonthlyCopy {
    final twelveMonths = (monthlyListPriceUsd * 12).toStringAsFixed(2);
    return 'Annual is $annualLabel (about $annualSavingsLabel; '
        '12 × $monthlyLabel is \$$twelveMonths).';
  }
}

/// Pure entitlement rules so tests do not need plugins or dart:io.
class EntitlementPolicy {
  const EntitlementPolicy._();

  /// `--dart-define=STUDY_GROVE_UNLOCK_PRO=true` for a local desktop build.
  /// Never a public Settings toggle in release.
  static const unlockProDefine = bool.fromEnvironment(
    'STUDY_GROVE_UNLOCK_PRO',
  );

  static bool isPro({
    required bool debugMode,
    required bool forceFree,
    required bool unlockDefine,
    required bool isWindows,
    required bool isLinux,
    required bool storePro,
  }) {
    if (debugMode && forceFree) return false;
    if (debugMode || unlockDefine || isWindows || isLinux) return true;
    return storePro;
  }

  static bool storeEnforcesIap({
    required bool debugMode,
    required bool isIOS,
    required bool isAndroid,
    required bool isMacOS,
  }) {
    if (debugMode) return false;
    return isIOS || isAndroid || isMacOS;
  }
}

/// Calendar-month allowance math. No Flutter or Firebase.
class AiAllowanceLogic {
  const AiAllowanceLogic._();

  static const monthlyLimit = SubscriptionCatalog.monthlyAiUses;

  static String monthKey(DateTime now) {
    final m = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  static DateTime nextReset(DateTime now) {
    return DateTime(now.year, now.month + 1, 1);
  }

  static ({String monthKey, int used}) applyReset({
    required String? storedMonth,
    required int storedUsed,
    required DateTime now,
  }) {
    final current = monthKey(now);
    if (storedMonth == current) {
      return (monthKey: current, used: storedUsed < 0 ? 0 : storedUsed);
    }
    return (monthKey: current, used: 0);
  }

  static int remaining(int used) {
    final left = monthlyLimit - used;
    return left < 0 ? 0 : left;
  }

  static bool canConsume(int used, [int units = 1]) {
    return used + units <= monthlyLimit;
  }
}
