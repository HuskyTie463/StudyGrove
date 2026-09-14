/// In-app Privacy Policy placeholder (no external law-firm URL).
///
/// Licence acceptance retention is documented here and in
/// [LicenceAcceptanceService]. We do not promise indefinite storage.
const studyGrovePrivacyPolicy = '''Study Grove — Privacy Policy

This in-app notice describes how Study Grove handles licence acceptance records and related account data. A fuller policy may be published later. This is not a third-party legal website.

Licence acceptance records

When you accept the Beta Software Licence Agreement, we record:
• your account ID (Firebase user id) if you are signed in
• the agreement version
• the acceptance date and time
• the app version
• the exact agreement text for that version

Signed-in accounts: records are stored in your cloud account (Firestore, under your user document, collection licenceAcceptances). Only your signed-in account can read or write those documents.

Without an account: records are stored only on this device. Clearing app data or reinstalling the app may remove that local record.

After you sign in, a guest acceptance for the current version is copied to your account so the same agreement is not asked twice when the versions match.

Retention

We do not store acceptance records indefinitely. They are retained for the life of the account plus a reasonable period after account deletion as required for legal defence (as described in this Privacy Policy; typically up to 7 years where lawful), then deleted with account deletion where lawful.

You can review the current Beta Software Licence Agreement in Settings.''';

const studyGrovePrivacyRetentionNote =
    'Licence acceptance records are kept for the life of the account plus a reasonable period after deletion as required for legal defence (as described in the Privacy Policy), then deleted with the account where lawful. Local guest records may be lost if you clear app data or reinstall.';

/// Short © + ™ line for Settings → Legal. Unregistered marks only (no ®).
const studyGroveCopyrightLine =
    '© 2026 Adara Curry. All rights reserved. Study Grove™ and the Study Grove logo are trademarks of Adara Curry.';

/// Public store support form. Inbox is not stored in the app.
const studyGroveSupportUrl =
    'https://huskytie463.github.io/StudyGrove/support/';
