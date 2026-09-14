import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_data_service.dart';
import '../services/study_ai_client.dart';
import '../services/study_ai_settings.dart';
import '../legal/privacy_policy_copy.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';
import 'licence_agreement_page.dart';
import 'privacy_policy_page.dart';
import 'settings_subscription_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and your data.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final providerIds = user.providerData.map((p) => p.providerId).toSet();
      final isPasswordAccount = providerIds.contains('password');

      if (isPasswordAccount) {
        final password = await _promptPassword(context);
        if (password == null || password.isEmpty) return;

        final email = user.email;
        if (email == null) {
          if (!context.mounted) return;
          _toast(context, 'No email found for this account.');
          return;
        }

        final cred =
            EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(cred);
      } else {
        if (!context.mounted) return;
        _toast(context, 'This account type needs provider re-auth.');
      }

      final uid = user.uid;
      await UserDataService(uid).deleteAllUserData();
      await studyAiSettings.clear();
      await user.delete();

      if (!context.mounted) return;
      _toast(context, 'Account deleted.');
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _toast(context, e.message ?? e.code);
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Delete failed: $e');
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result;
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSupport(BuildContext context) async {
    final uri = Uri.parse(studyGroveSupportUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _toast(context, 'Could not open the support page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '(no email)';
    final t = context.tokens;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(t.gap(2)),
        children: [
          Text(
            'Signed in as $email',
            style: TextStyle(color: t.textMuted),
          ),
              SizedBox(height: t.gap(3)),
              const SettingsSubscriptionCard(),
              SizedBox(height: t.gap(3)),
              const _StudyAiKeyCard(),
              SizedBox(height: t.gap(3)),
              Text(
                'Colour themes, wallpaper, and light/dark live in the top bar — paint menu and Backgrounds.',
                style: TextStyle(color: t.textMuted, height: 1.4),
              ),
              const Divider(),
              Text('Legal', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.gap(1)),
              Text(
                studyGroveCopyrightLine,
                style: TextStyle(color: t.textMuted, height: 1.4, fontSize: 13),
              ),
              SizedBox(height: t.gap(1)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Beta Software Licence Agreement'),
                subtitle: const Text('Review the current agreement.'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LicenceAgreementPage(
                      mode: LicenceAgreementMode.review,
                    ),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text(
                  'How licence acceptance is stored and retained.',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Support'),
                subtitle: const Text(
                  'Opens the public support form. Replies come by email.',
                ),
                onTap: () => _openSupport(context),
              ),
              Text(
                studyGrovePrivacyRetentionNote,
                style: TextStyle(color: t.textMuted, height: 1.4, fontSize: 13),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever, color: t.destructive),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: t.destructive),
                ),
                subtitle:
                    const Text('Deletes your data + account permanently.'),
                onTap: () => _deleteAccount(context),
              ),
        ],
      ),
    );
  }
}

class _StudyAiKeyCard extends StatefulWidget {
  const _StudyAiKeyCard();

  @override
  State<_StudyAiKeyCard> createState() => _StudyAiKeyCardState();
}

class _StudyAiKeyCardState extends State<_StudyAiKeyCard> {
  final _ctrl = TextEditingController();
  final _ttsCtrl = TextEditingController();
  var _obscure = true;
  var _ttsObscure = true;
  var _saving = false;
  var _savingTts = false;
  var _testing = false;
  var _advanced = false;
  String? _status;
  String? _ttsStatus;

  @override
  void dispose() {
    _ctrl.dispose();
    _ttsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: studyAiSettings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Study AI', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: t.gap(0.75)),
            Text(
              studyAiSettings.usingCustomKey
                  ? 'Using a custom key you saved on this device. It is sent only to ${studyAiSettings.provider.label}.'
                  : 'Study AI is built in. Open Advanced only if you want to use your own key.',
              style: TextStyle(color: t.textMuted, height: 1.45, fontSize: 13),
            ),
            SizedBox(height: t.gap(1.5)),
            SegmentedButton<StudyAiProvider>(
              segments: const [
                ButtonSegment(
                  value: StudyAiProvider.openai,
                  label: Text('OpenAI'),
                ),
                ButtonSegment(
                  value: StudyAiProvider.anthropic,
                  label: Text('Anthropic'),
                ),
              ],
              selected: {studyAiSettings.provider},
              onSelectionChanged: (v) => studyAiSettings.setProvider(v.first),
            ),
            if (_status != null) ...[
              SizedBox(height: t.gap(0.75)),
              Text(_status!, style: TextStyle(color: t.textSecondary, fontSize: 13)),
            ],
            SizedBox(height: t.gap(1.5)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SgSecondaryButton(
                  label: _testing ? 'Testing…' : 'Test Study AI',
                  onPressed: _testing ? null : _test,
                ),
              ],
            ),
            SizedBox(height: t.gap(2)),
            TextButton(
              onPressed: () => setState(() => _advanced = !_advanced),
              child: Text(
                _advanced ? 'Hide advanced keys' : 'Advanced: use my own keys',
              ),
            ),
            if (_advanced) ...[
              SizedBox(height: t.gap(1)),
              Text(
                'Optional. Leave blank to keep using the server. Fields stay hidden and are never pre-filled.',
                style: TextStyle(color: t.textMuted, height: 1.4, fontSize: 13),
              ),
              SizedBox(height: t.gap(1.5)),
              TextField(
                controller: _ctrl,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: '${studyAiSettings.provider.label} key',
                  hintText: studyAiSettings.provider.keyHint,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              SizedBox(height: t.gap(1.5)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SgPrimaryButton(
                    label: _saving ? 'Saving…' : 'Save key',
                    onPressed: _saving ? null : _save,
                  ),
                  if (studyAiSettings.usingCustomKey)
                    SgSecondaryButton(
                      label: 'Use built-in',
                      onPressed: () async {
                        await studyAiSettings.resetToBundled();
                        _ctrl.clear();
                        setState(() => _status = 'Using built-in Study AI.');
                      },
                    ),
                ],
              ),
              SizedBox(height: t.gap(2)),
              Text(
                'Listen / Voice Chat OpenAI key',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: t.gap(1)),
              TextField(
                controller: _ttsCtrl,
                obscureText: _ttsObscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'OpenAI key for Listen',
                  hintText: studyAiSettings.provider.keyHint,
                  suffixIcon: IconButton(
                    tooltip: _ttsObscure ? 'Show' : 'Hide',
                    onPressed: () => setState(() => _ttsObscure = !_ttsObscure),
                    icon: Icon(
                      _ttsObscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_ttsStatus != null) ...[
                SizedBox(height: t.gap(0.75)),
                Text(
                  _ttsStatus!,
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              ],
              SizedBox(height: t.gap(1.5)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SgPrimaryButton(
                    label: _savingTts ? 'Saving…' : 'Save Listen key',
                    onPressed: _savingTts ? null : _saveTts,
                  ),
                  if (studyAiSettings.usingCustomTtsKey)
                    SgSecondaryButton(
                      label: 'Use built-in Listen',
                      onPressed: () async {
                        await studyAiSettings.setTtsOpenAiKey('');
                        _ttsCtrl.clear();
                        setState(
                          () => _ttsStatus = 'Listen uses the built-in key.',
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await studyAiSettings.setApiKey(_ctrl.text);
      _ctrl.clear();
      setState(() => _status = studyAiSettings.usingCustomKey
          ? 'Custom key saved on this device.'
          : 'Using built-in Study AI.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      if (_advanced && _ctrl.text.trim().isNotEmpty) {
        await studyAiSettings.setApiKey(_ctrl.text);
        _ctrl.clear();
      }
      final reply = await StudyAiClient.instance.complete(
        system: 'Reply with exactly: ok',
        user: 'ping',
        maxTokens: 16,
        countTowardAllowance: false,
      );
      setState(() => _status = reply.toLowerCase().contains('ok')
          ? 'Study AI is working.'
          : 'Got a reply: ${reply.trim()}');
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveTts() async {
    setState(() => _savingTts = true);
    try {
      await studyAiSettings.setTtsOpenAiKey(_ttsCtrl.text);
      _ttsCtrl.clear();
      setState(
        () => _ttsStatus = studyAiSettings.usingCustomTtsKey
            ? 'Custom Listen key saved on this device.'
            : 'Listen uses the built-in key.',
      );
    } catch (e) {
      setState(() => _ttsStatus = e.toString());
    } finally {
      if (mounted) setState(() => _savingTts = false);
    }
  }
}
