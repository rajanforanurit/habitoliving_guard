import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Verify a visitor pass at the gate.
///
/// The pass is an OTP or QR code the resident issued. The guard types it (or
/// scans it on a device with a camera), the backend checks it is live and inside
/// its valid window, and only then does the screen show a green admitted state.
///
/// There is no "admit anyway" button. A pass that fails to verify is a failed
/// verification: the guard registers the person as a walk-in instead, which goes
/// back to the resident for a decision.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  Visitor? _visitor;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the pass code shown to the resident.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _visitor = null;
    });
    try {
      final visitor = await AppServices.instance.guard.verifyPass(code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _visitor = visitor;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _entry(Visitor visitor) async {
    try {
      await AppServices.instance.guard.recordEntry(visitor.id);
      if (!mounted) return;
      showMessage(context, 'Entry recorded.');
      setState(() => _visitor = null);
      _code.clear();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verify a pass',
      subtitle: 'OTP or QR from a resident',
      body: _visitor != null
          ? _Verified(
              visitor: _visitor!,
              onEntry: _entry,
              onClear: () {
                setState(() => _visitor = null);
                _code.clear();
              },
            )
          : ListView(
              padding: EdgeInsets.only(
                left: Tokens.gutter,
                right: Tokens.gutter,
                bottom: kScreenBottomPadding,
              ),
              children: [
                Text(
                  'Ask the resident to show the pass in their app. The code is six digits, or '
                  'the QR from the same screen.',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    height: 1.5,
                    color: Tokens.inkMuted,
                  ),
                ),
                SizedBox(height: Tokens.space5),
                TextField(
                  controller: _code,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _verify(),
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    fontFamily: Tokens.fontMono,
                    fontSize: 26,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Pass code',
                    hintText: '000000',
                    prefixIcon: AppIcon(Icons2.scan, size: IconSize.header),
                  ),
                ),
                if (_error != null) ...[
                  SizedBox(height: Tokens.space4),
                  Container(
                    padding: EdgeInsets.all(Tokens.space3),
                    decoration: BoxDecoration(
                      color: Tokens.dangerTint,
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(
                          Icons2.error,
                          size: IconSize.inline,
                          color: Tokens.danger,
                        ),
                        SizedBox(width: Tokens.space2),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: Tokens.fontFamily,
                              fontSize: Tokens.typeSm,
                              height: 1.45,
                              color: Tokens.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: Tokens.space5),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.accent,
                    minimumSize: const Size.fromHeight(Tokens.controlHeight),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Tokens.accentOn,
                          ),
                        )
                      : const Text('Verify'),
                ),
                SizedBox(height: Tokens.space6),
                Panel(
                  child: Padding(
                    padding: EdgeInsets.all(Tokens.space4),
                    child: Text(
                      'A code that does not verify is not an entry. Register the person as a '
                      'walk-in instead, so the resident can decide.',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        height: 1.5,
                        color: Tokens.inkFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The result of a successful verification.
class _Verified extends StatelessWidget {
  const _Verified({
    required this.visitor,
    required this.onEntry,
    required this.onClear,
  });

  final Visitor visitor;
  final Future<void> Function(Visitor) onEntry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final checkedIn = visitor.status == VisitorStatusValue.checkedIn;
    return ListView(
      padding: EdgeInsets.all(Tokens.space4),
      children: [
        SizedBox(height: Tokens.space3),
        Container(
          padding: EdgeInsets.all(Tokens.space5),
          decoration: BoxDecoration(
            color: checkedIn ? Tokens.accentTint : Tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(
              color: checkedIn
                  ? Tokens.accent.withValues(alpha: 0.3)
                  : Tokens.line,
            ),
          ),
          child: Column(
            children: [
              AppIcon(
                checkedIn ? Icons2.success : Icons2.visitors,
                size: IconSize.empty,
                color: checkedIn ? Tokens.accent : Tokens.inkMuted,
              ),
              SizedBox(height: Tokens.space3),
              Text(
                checkedIn
                    ? 'Pass is valid and already inside'
                    : 'Pass is valid',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeMd,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              SizedBox(height: Tokens.space1),
              Text(
                'This pass is live and inside its valid window.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  color: Tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        Panel(
          child: Column(
            children: [
              ListRow(
                dense: true,
                title: 'Visitor',
                subtitle: visitor.name,
                leading: const AppIcon(Icons2.profile, size: IconSize.row),
                showChevron: false,
              ),
              if (visitor.flatLabel != null)
                const Hairline(indent: Tokens.space4),
              if (visitor.flatLabel != null)
                ListRow(
                  dense: true,
                  title: 'Going to',
                  subtitle: visitor.flatLabel,
                  leading: const AppIcon(Icons2.flat, size: IconSize.row),
                  showChevron: false,
                ),
              if (visitor.phone != null) ...[
                const Hairline(indent: Tokens.space4),
                ListRow(
                  dense: true,
                  title: 'Phone',
                  subtitle: Fmt.phone(visitor.phone),
                  leading: const AppIcon(Icons2.phone, size: IconSize.row),
                  showChevron: false,
                ),
              ],
              if (visitor.purpose != null) ...[
                const Hairline(indent: Tokens.space4),
                ListRow(
                  dense: true,
                  title: 'Purpose',
                  subtitle: visitor.purpose,
                  leading: const AppIcon(Icons2.info, size: IconSize.row),
                  showChevron: false,
                ),
              ],
              if (visitor.vehicleNumber != null) ...[
                const Hairline(indent: Tokens.space4),
                ListRow(
                  dense: true,
                  title: 'Vehicle',
                  subtitle: Fmt.plate(visitor.vehicleNumber),
                  leading: const AppIcon(Icons2.vehicles, size: IconSize.row),
                  showChevron: false,
                ),
              ],
              const Hairline(indent: Tokens.space4),
              ListRow(
                dense: true,
                title: 'Status',
                trailing: StatusBadge.forStatus(visitor.status.name),
                leading: const AppIcon(Icons2.pending, size: IconSize.row),
                showChevron: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space5),
        if (!checkedIn)
          FilledButton(
            onPressed: () => onEntry(visitor),
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.accent,
              minimumSize: const Size.fromHeight(Tokens.controlHeight),
            ),
            child: const Text('Record entry'),
          ),
        const SizedBox(height: Tokens.space2),
        OutlinedButton(
          onPressed: onClear,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(Tokens.controlHeight),
          ),
          child: const Text('Verify another pass'),
        ),
      ],
    );
  }
}
