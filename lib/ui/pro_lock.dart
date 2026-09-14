import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ProLockBadge extends StatelessWidget {
  const ProLockBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: compact ? 14 : 16, color: t.textMuted),
        SizedBox(width: compact ? 4 : 6),
        Text(
          'Pro',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 11 : 12,
            color: t.textMuted,
          ),
        ),
      ],
    );
  }
}

class AiUsesLeftLabel extends StatelessWidget {
  const AiUsesLeftLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.35),
    );
  }
}
