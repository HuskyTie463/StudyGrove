/// Store SKUs for Study Grove Pro. Monthly only — no annual plan.
///
/// Create these exact products:
///
/// **App Store Connect** (Subscriptions, bundle `com.adaracurry.studygrove`)
/// — `pro_monthly`: Auto-Renewable, 1 month, USD 4.95
/// Keep this ID. Renaming it would require a new App Store product.
/// Enable In-App Purchase on the App ID for iOS and macOS.
///
/// **Google Play Console** (Subscriptions, package `com.adaracurry.studygrove`)
/// — Subscription product `pro_monthly` with a monthly base plan, USD 4.95
/// Keep this ID. Billing permission is merged from `in_app_purchase`.
///
/// **Microsoft Partner Center** (add-on on the Study Grove app)
/// — Product identity the app queries: `studygrove_pro_monthly`
/// — Listing Store ID (comments / Store page only, not the query key): `9PP0RQTCQ47R`
/// — List price must be USD 4.95 (matches in-app fallback `US$4.95 / month`)
/// Submit the **app package first**, then finish the add-on. Until both are
/// published, checkout may fail in production. Associate the Windows package
/// with the Partner Center product (Package identity / Store association).
/// Debug builds still unlock via `kDebugMode` / `STUDY_GROVE_UNLOCK_PRO`.
/// Release Store builds require this add-on — they do not auto-unlock.
class SubscriptionCatalog {
  static const monthlyProductId = 'pro_monthly';

  /// Partner Center add-on identity. Must match the ID the Windows app queries.
  static const windowsMonthlyProductId = 'studygrove_pro_monthly';

  /// Partner Center listing id for the add-on. Do not pass this to Store queries.
  static const windowsStoreListingId = '9PP0RQTCQ47R';

  static const monthlyListPriceUsd = 4.95;
  /// Fallback when WinRT / IAP has not returned a live formatted price.
  static const monthlyLabel = r'US$4.95 / month';

  /// Calendar-month Study AI uses included with Pro.
  static const monthlyAiUses = 40;

  /// Extra Voice Chat use charged after this many minutes in one session.
  static const voiceExtraUseMinutes = 8;

  /// Mobile / Mac App Store product query set.
  static const productIds = <String>{
    monthlyProductId,
  };

  /// Any store product that grants Pro (Apple/Play monthly + Windows add-on).
  static const recognizedProductIds = <String>{
    monthlyProductId,
    windowsMonthlyProductId,
  };

  static const allowanceLine = '$monthlyAiUses Study AI uses / month';

  static const windowsAddOnNotListedMessage =
      'Pro unlocks after Study Grove is listed in the Microsoft Store. '
      'Purchase will work for Store-installed builds.';

  static const windowsManageSubscriptionsUri = 'ms-windows-store://account';

  static bool grantsPro(String productId) =>
      recognizedProductIds.contains(productId);
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
    required bool isLinux,
    required bool storePro,
  }) {
    if (debugMode && forceFree) return false;
    if (debugMode || unlockDefine || isLinux) return true;
    return storePro;
  }

  static bool storeEnforcesIap({
    required bool debugMode,
    required bool isIOS,
    required bool isAndroid,
    required bool isMacOS,
    required bool isWindows,
  }) {
    if (debugMode) return false;
    return isIOS || isAndroid || isMacOS || isWindows;
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
