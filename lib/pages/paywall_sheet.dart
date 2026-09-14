import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_allowance_service.dart';
import '../services/entitlement_service.dart';
import '../services/subscription_catalog.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';

enum PaywallReason { lockedFeature, allowance }

Future<void> showStudyGrovePaywall(
  BuildContext context, {
  PaywallReason reason = PaywallReason.lockedFeature,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PaywallSheet(reason: reason),
  );
}

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({
    super.key,
    this.reason = PaywallReason.lockedFeature,
  });

  final PaywallReason reason;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: Listenable.merge([entitlementService, aiAllowanceService]),
      builder: (context, _) {
        final monthly = entitlementService.priceLabel(
          entitlementService.unlockProductId,
          SubscriptionCatalog.monthlyLabel,
        );
        final onWindows = defaultTargetPlatform == TargetPlatform.windows;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(t.gap(2.5), 0, t.gap(2.5), t.gap(2.5)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: t.primaryAction),
                      SizedBox(width: t.gap(1)),
                      Text(
                        reason == PaywallReason.allowance
                            ? 'Monthly Study AI uses are used up'
                            : 'Study + Study AI are Pro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  SizedBox(height: t.gap(1)),
                  Text(
                    reason == PaywallReason.allowance
                        ? 'You have used this month’s ${SubscriptionCatalog.monthlyAiUses} Study AI uses. '
                            'They reset on ${formatAllowanceReset(aiAllowanceService.resetsOn)}. '
                            'Home, Plan, and Subjects stay open.'
                        : 'Free includes Home, Plan, and Subjects. '
                            'Pro unlocks the Study section and built-in Study AI.',
                    style: TextStyle(color: t.textMuted, height: 1.45),
                  ),
                  SizedBox(height: t.gap(2)),
                  const _PlanCard(
                    title: 'Free',
                    price: 'Included',
                    points: [
                      'Home — Dashboard, Time, Notes',
                      'Plan — Planner, Calendar, Weekly Planner, Assessments',
                      'Subjects',
                    ],
                  ),
                  SizedBox(height: t.gap(1.5)),
                  _PlanCard(
                    title: 'Pro',
                    price: monthly,
                    highlight: true,
                    points: const [
                      'Everything in Free',
                      'Lecture Lab, Review, Voice Chat, Study Roulette, Pomodoro',
                      'Study AI — extract, quizzes, flashcards, listen, voice',
                      '${SubscriptionCatalog.monthlyAiUses} Study AI uses / month',
                    ],
                  ),
                  if (onWindows) ...[
                    SizedBox(height: t.gap(1)),
                    Text(
                      'Unlock Pro opens the Microsoft Store checkout for the '
                      'monthly subscription. Manage it from your Store account.',
                      style: TextStyle(
                        color: t.textMuted,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (onWindows &&
                      !entitlementService.isPro &&
                      !entitlementService.windowsAddOnListed) ...[
                    SizedBox(height: t.gap(1)),
                    Text(
                      SubscriptionCatalog.windowsAddOnNotListedMessage,
                      style: TextStyle(
                        color: t.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (entitlementService.status != null) ...[
                    SizedBox(height: t.gap(1)),
                    Text(
                      entitlementService.status!,
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ],
                  SizedBox(height: t.gap(2)),
                  if (reason != PaywallReason.allowance ||
                      !entitlementService.isPro) ...[
                    SgPrimaryButton(
                      label: entitlementService.busy
                          ? 'Working…'
                          : 'Unlock Pro · $monthly',
                      expanded: true,
                      onPressed: entitlementService.busy
                          ? null
                          : entitlementService.unlockPro,
                    ),
                    SizedBox(height: t.gap(1)),
                    SgSecondaryButton(
                      label: 'Restore',
                      onPressed: entitlementService.busy
                          ? null
                          : entitlementService.restorePurchases,
                    ),
                  ] else
                    Text(
                      'Pro includes ${SubscriptionCatalog.monthlyAiUses} Study AI uses each month. '
                      'Wait for the reset date, or use your own key in Settings → Advanced.',
                      style: TextStyle(color: t.textMuted, height: 1.45),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.points,
    this.highlight = false,
  });

  final String title;
  final String price;
  final List<String> points;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SgCard(
      accent: highlight ? t.primaryAction : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (highlight)
                SgStatusTag(
                  label: 'Pro',
                  color: t.primaryAction,
                  icon: Icons.workspace_premium_outlined,
                ),
            ],
          ),
          SizedBox(height: t.gap(0.5)),
          Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: t.primaryAction,
            ),
          ),
          SizedBox(height: t.gap(1)),
          for (final point in points)
            Padding(
              padding: EdgeInsets.only(bottom: t.gap(0.5)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 16, color: t.primaryAction),
                  SizedBox(width: t.gap(0.75)),
                  Expanded(
                    child: Text(point, style: const TextStyle(height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> openManageSubscriptions() async {
  final uri = switch (defaultTargetPlatform) {
    TargetPlatform.android => Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=com.adaracurry.studygrove',
      ),
    TargetPlatform.windows =>
      Uri.parse(SubscriptionCatalog.windowsManageSubscriptionsUri),
    _ => Uri.parse('https://apps.apple.com/account/subscriptions'),
  };
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
