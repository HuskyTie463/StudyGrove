import 'package:flutter/material.dart';

import '../legal/privacy_policy_copy.dart';
import '../theme/design_tokens.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>();
    final pad = tokens?.gap(2) ?? 16.0;
    final body =
        tokens?.textPrimary ?? Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          semanticsLabel: 'Privacy Policy',
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Semantics(
              container: true,
              label: 'Privacy Policy',
              child: SelectableText(
                studyGrovePrivacyPolicy,
                style: TextStyle(color: body, height: 1.45, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
