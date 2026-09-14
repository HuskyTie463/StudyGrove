import 'package:flutter/material.dart';

import '../legal/leave_app.dart';
import '../services/licence_acceptance_service.dart';
import 'licence_agreement_page.dart';

/// Gates the main app until a confirmed acceptance exists for the
/// current required version. Existing signed-in accounts with no cloud
/// record are asked; guests with no local record are asked. Not limited
/// to a brand-new first install. Waits until auth has settled ([uid]
/// known or explicitly guest). Does not treat dialog appearance as
/// acceptance.
class LicenceGate extends StatefulWidget {
  const LicenceGate({
    super.key,
    required this.child,
    this.uid,
    this.service,
  });

  final Widget child;
  final String? uid;
  final LicenceAcceptanceService? service;

  @override
  State<LicenceGate> createState() => _LicenceGateState();
}

class _LicenceGateState extends State<LicenceGate> {
  var _checking = true;
  var _needsDialog = false;

  LicenceAcceptanceService get _service =>
      widget.service ?? licenceAcceptanceService;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LicenceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() => _checking = true);
    final needs = await _service.needsAcceptance(uid: widget.uid);
    if (!mounted) return;
    setState(() {
      _needsDialog = needs;
      _checking = false;
    });
  }

  Future<void> _onAccept() async {
    await _service.accept(uid: widget.uid);
    if (!mounted) return;
    setState(() => _needsDialog = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Checking licence agreement',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_needsDialog) {
      return LicenceAgreementPage(
        mode: LicenceAgreementMode.accept,
        service: _service,
        onAccept: _onAccept,
        onDecline: leaveStudyGrove,
      );
    }
    return widget.child;
  }
}
