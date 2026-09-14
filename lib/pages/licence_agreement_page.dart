import 'package:flutter/material.dart';

import '../legal/beta_licence.dart';
import '../legal/leave_app.dart';
import '../legal/privacy_policy_copy.dart';
import '../services/licence_acceptance_service.dart';
import '../theme/design_tokens.dart';
import 'privacy_policy_page.dart';

enum LicenceAgreementMode { accept, review }

/// Scrollable, keyboard-accessible Beta Software Licence Agreement.
class LicenceAgreementPage extends StatefulWidget {
  const LicenceAgreementPage({
    super.key,
    this.mode = LicenceAgreementMode.accept,
    this.onAccept,
    this.onDecline,
    this.onOpenPrivacy,
    this.service,
  });

  final LicenceAgreementMode mode;
  final Future<void> Function()? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onOpenPrivacy;
  final LicenceAcceptanceService? service;

  @override
  State<LicenceAgreementPage> createState() => _LicenceAgreementPageState();
}

class _LicenceAgreementPageState extends State<LicenceAgreementPage> {
  var _agreed = false;
  var _saving = false;
  String? _error;
  final _scrollController = ScrollController();

  bool get _review => widget.mode == LicenceAgreementMode.review;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onAccept != null) {
        await widget.onAccept!();
      } else {
        await (widget.service ?? licenceAcceptanceService).accept();
        if (mounted) Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is LicenceSaveException
            ? e.message
            : LicenceSaveException.saveFailedMessage;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _decline() {
    if (widget.onDecline != null) {
      widget.onDecline!();
      return;
    }
    leaveStudyGrove();
  }

  void _openPrivacy() {
    if (widget.onOpenPrivacy != null) {
      widget.onOpenPrivacy!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>();
    final scheme = Theme.of(context).colorScheme;
    final muted = tokens?.textMuted ?? scheme.onSurface.withValues(alpha: 0.68);
    final body = tokens?.textPrimary ?? scheme.onSurface;
    final pad = tokens?.gap(2) ?? 16.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: _review,
        title: const Text(
          BetaLicence.title,
          semanticsLabel: BetaLicence.title,
        ),
      ),
      body: SafeArea(
        child: FocusTraversalGroup(
          child: Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    primary: false,
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                    child: Semantics(
                      container: true,
                      label: 'Beta Software Licence Agreement, version ${BetaLicence.currentVersion}',
                      child: SelectableText(
                        BetaLicence.currentText,
                        style: TextStyle(
                          color: body,
                          height: 1.45,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!_review) ...[
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, pad / 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: BetaLicence.checkboxLabel,
                        checked: _agreed,
                        child: CheckboxListTile(
                          value: _agreed,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _agreed = v ?? false),
                          title: Text(BetaLicence.checkboxLabel),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: pad / 2),
                        Semantics(
                          liveRegion: true,
                          label: _error,
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.error, height: 1.35),
                          ),
                        ),
                      ],
                      SizedBox(height: pad / 2),
                      Semantics(
                        button: true,
                        enabled: _agreed && !_saving,
                        label: BetaLicence.agreeButtonLabel,
                        child: FilledButton(
                          onPressed:
                              (_agreed && !_saving) ? _accept : null,
                          child: Text(
                            _saving ? 'Saving…' : BetaLicence.agreeButtonLabel,
                          ),
                        ),
                      ),
                      SizedBox(height: pad / 2),
                      Semantics(
                        button: true,
                        enabled: !_saving,
                        label: BetaLicence.declineButtonLabel,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _decline,
                          child: const Text(BetaLicence.declineButtonLabel),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          link: true,
                          label: BetaLicence.privacyLinkLabel,
                          hint: studyGrovePrivacyRetentionNote,
                          child: TextButton(
                            onPressed: _openPrivacy,
                            child: const Text(BetaLicence.privacyLinkLabel),
                          ),
                        ),
                      ),
                      Text(
                        'You can review this agreement and the Privacy Policy later in Settings.',
                        style: TextStyle(color: muted, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: EdgeInsets.all(pad),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      link: true,
                      label: BetaLicence.privacyLinkLabel,
                      child: TextButton(
                        onPressed: _openPrivacy,
                        child: const Text(BetaLicence.privacyLinkLabel),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
