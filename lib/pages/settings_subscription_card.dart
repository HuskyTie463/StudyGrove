import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/ai_allowance_service.dart';
import '../services/entitlement_service.dart';
import '../services/study_ai_settings.dart';
import '../services/subscription_catalog.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';
import 'paywall_sheet.dart';

class SettingsSubscriptionCard extends StatelessWidget {
  const SettingsSubscriptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: Listenable.merge([
        entitlementService,
        aiAllowanceService,
        studyAiSettings,
      ]),
      builder: (context, _) {
        final monthly = entitlementService.priceLabel(
          entitlementService.unlockProductId,
          SubscriptionCatalog.monthlyLabel,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: t.gap(0.75)),
            Text(
              entitlementService.isPro
                  ? 'You are on ${entitlementService.planLabel}.'
                  : 'You are on Free. Home, Plan, and Subjects are open. '
                      'Study and Study AI need Pro ($monthly).',
              style: TextStyle(color: t.textMuted, height: 1.45, fontSize: 13),
            ),
            SizedBox(height: t.gap(1.25)),
            Text(
              studyAiSettings.usingCustomKey
                  ? 'Using your own key — Study AI uses do not count toward the monthly allowance.'
                  : aiAllowanceService.remainingLabel,
              style: TextStyle(color: t.textSecondary, height: 1.4, fontSize: 13),
            ),
            if (entitlementService.isPro && !studyAiSettings.usingCustomKey) ...[
              SizedBox(height: t.gap(0.5)),
              Text(
                'Resets on ${formatAllowanceReset(aiAllowanceService.resetsOn)}. '
                '${SubscriptionCatalog.allowanceLine}.',
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4),
              ),
            ],
            if (entitlementService.status != null) ...[
              SizedBox(height: t.gap(0.75)),
              Text(
                entitlementService.status!,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
            SizedBox(height: t.gap(1.5)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!entitlementService.isPro)
                  SgPrimaryButton(
                    label: 'Subscribe · $monthly',
                    onPressed: () => showStudyGrovePaywall(context),
                  ),
                SgSecondaryButton(
                  label: 'Restore',
                  onPressed: entitlementService.busy
                      ? null
                      : entitlementService.restorePurchases,
                ),
                SgSecondaryButton(
                  label: 'Manage',
                  onPressed: openManageSubscriptions,
                ),
              ],
            ),
            if (kDebugMode) ...[
              SizedBox(height: t.gap(2)),
              Text(
                'Developer (debug only)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: t.gap(0.5)),
              Text(
                'Debug builds are Pro so you can use Study. '
                'Force Free only to test locks. Release Microsoft Store builds '
                'need the monthly subscription — they do not auto-unlock.',
                style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.4),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Force Free (test paywall)'),
                value: entitlementService.forceFreeForTesting,
                onChanged: entitlementService.setForceFreeForTesting,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: aiAllowanceService.resetForTesting,
                  child: const Text('Reset Study AI uses this month'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
