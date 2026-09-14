/// Canonical Beta Software Licence Agreement texts, keyed by version.
///
/// When terms are materially revised, add a new version string higher than
/// [currentVersion], store its full body here, and bump [currentVersion].
/// Previous versions stay in [bodiesByVersion] so historical acceptances
/// keep the exact text the user agreed to.
class BetaLicence {
  static const currentVersion = '1.0';
  static const effectiveDate = '14/09/2026';
  static const publisher = 'Adara Curry';
  static const title = 'Study Grove — Beta Software Licence Agreement';

  /// Checkbox label is UI-only and is not part of the stored agreement body.
  static const checkboxLabel =
      'I have read and agree to the Beta Software Licence Agreement and understand that Study Grove is currently in beta testing.';

  static const agreeButtonLabel = 'I agree and continue';
  static const declineButtonLabel = 'Decline and exit';
  static const privacyLinkLabel = 'Privacy Policy';

  static const bodyV1_0 = '''Study Grove — Beta Software Licence Agreement

Version 1.0 · Effective date: 14/09/2026
Publisher: Adara Curry

Welcome to Study Grove! Thank you for helping us test and improve the app. Please read this agreement before continuing.

Your licence

The publisher grants you a limited, non-exclusive licence to use Study Grove for your own personal organisation and study activities, subject to this agreement and any applicable purchase or subscription terms. Ownership of the software remains with the publisher and its licensors.

Beta testing notice

Study Grove is currently in beta testing. Features may contain bugs, produce unexpected results, or experience interruptions. Saving, syncing, reminders and AI features may occasionally fail or provide incorrect information.

Keep separate copies of important notes and information, and use a backup reminder for critical commitments.

Check important information

Study Grove provides personal planning tools, study assistance and general information. It does not guarantee academic results or replace official instructions or professional advice.

Always independently check important dates, times, time zones, deadlines, schedules and AI-generated information against reliable sources, such as your school’s official timetable or assessment instructions. AI-generated answers, explanations and references may be inaccurate or incomplete.

Your rights and limitations of liability

Nothing in this agreement excludes or restricts consumer rights, statutory guarantees, refunds, remedies or liability that cannot lawfully be excluded or restricted.

Subject to those rights, we do not promise that every beta feature or AI-generated response will be error-free or continuously available. To the extent permitted by applicable law, we are not liable for losses that were not reasonably foreseeable. This limitation does not apply to fraud, wilful misconduct or liability that cannot lawfully be limited.

Acceptance record

When you accept, we record your acceptance, the agreement version and the acceptance date and time. Information about how this record is stored and retained is available in our Privacy Policy.

You can review this agreement again in the app’s settings.''';

  static const bodiesByVersion = <String, String>{
    '1.0': bodyV1_0,
  };

  static String textForVersion(String version) {
    return bodiesByVersion[version] ?? bodyV1_0;
  }

  static String get currentText => textForVersion(currentVersion);

  /// Returns a positive number when [required] is higher than [accepted].
  static int compareVersions(String required, String accepted) {
    List<int> parts(String v) => v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final a = parts(required);
    final b = parts(accepted);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  static bool needsFreshAcceptance(String? lastAcceptedVersion) {
    if (lastAcceptedVersion == null || lastAcceptedVersion.isEmpty) {
      return true;
    }
    return compareVersions(currentVersion, lastAcceptedVersion) > 0;
  }
}
