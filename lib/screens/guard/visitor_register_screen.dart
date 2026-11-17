import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Register a walk-in visitor at the gate.
///
/// The guard cannot invent a flat, so the destination is a lookup: type part of
/// the flat label, pick the match. Then the visitor's name, and optionally a
/// phone, purpose and vehicle number.
///
/// Registration does not admit anyone. It sends the request to the resident,
/// who approves or refuses; the result screen says exactly that, so a guard
/// never tells a visitor they are in before the resident agrees.
class VisitorRegisterScreen extends StatefulWidget {
  const VisitorRegisterScreen({super.key});

  @override
  State<VisitorRegisterScreen> createState() => _VisitorRegisterScreenState();
}

class _VisitorRegisterScreenState extends State<VisitorRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _purpose = TextEditingController();
  final _vehicle = TextEditingController();
  final _flatQuery = TextEditingController();

  List<Map<String, dynamic>> _matches = [];
  Map<String, dynamic>? _flat;
  bool _searching = false;
  bool _busy = false;
  String? _error;
  String? _visitorName;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _purpose.dispose();
    _vehicle.dispose();
    _flatQuery.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() => _matches = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await AppServices.instance.guard.lookupFlat(q);
      if (!mounted) return;
      setState(() => _matches = found);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (_flat == null) {
      showMessage(
        context,
        'Choose the flat this visitor is going to.',
        error: true,
      );
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final visitor = await AppServices.instance.guard.registerVisitor(
        name: _name.text.trim(),
        flatId: _flat!['id']?.toString() ?? '',
        phone: _phone.text.trim(),
        purpose: _purpose.text.trim(),
        vehicleNumber: _vehicle.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _visitorName = visitor.name;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visitorName != null) {
      return AppScaffold(
        title: 'Visitor registered',
        showBack: false,
        body: _SentState(
          name: _visitorName!,
          onDone: () => Navigator.of(context).pop(true),
        ),
      );
    }

    return AppScaffold(
      title: 'Register a visitor',
      subtitle: 'Walk-in entry request',
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kScreenBottomPadding),
          children: [
            // 1. The flat, because everything else is optional.
            SectionLabel('Going to'),
            SizedBox(height: Tokens.space2),
            TextField(
              controller: _flatQuery,
              textInputAction: TextInputAction.search,
              onChanged: (v) => _search(v),
              decoration: const InputDecoration(
                labelText: 'Flat, tower or resident name',
                prefixIcon: AppIcon(Icons2.search, size: IconSize.inline),
              ),
            ),
            if (_flat != null) ...[
              const SizedBox(height: Tokens.space2),
              _ChosenFlat(
                flat: _flat!,
                onClear: () => setState(() => _flat = null),
              ),
            ],
            if (_searching) ...[
              SizedBox(height: Tokens.space2),
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Tokens.surfaceSunken,
                color: Tokens.accent,
              ),
            ],
            if (_matches.isNotEmpty && _flat == null) ...[
              const SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    for (var i = 0; i < _matches.length; i++) ...[
                      if (i > 0) const Hairline(indent: Tokens.space4),
                      ListRow(
                        dense: true,
                        title: _flatLabel(_matches[i]),
                        subtitle: _flatSub(_matches[i]),
                        leading: const AppIcon(Icons2.flat, size: IconSize.row),
                        onTap: () => setState(() {
                          _flat = _matches[i];
                          _matches = const [];
                          _flatQuery.clear();
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_matches.isEmpty && !_searching && _flat == null) ...[
              SizedBox(height: Tokens.space2),
              Text(
                'Type at least two characters of the flat number or the resident\'s name.',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  color: Tokens.inkFaint,
                ),
              ),
            ],

            SizedBox(height: Tokens.space5),
            SectionLabel('The visitor'),
            SizedBox(height: Tokens.space2),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter the visitor\'s name'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: AppIcon(Icons2.profile, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: AppIcon(Icons2.phone, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _purpose,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Purpose (optional)',
                prefixIcon: AppIcon(Icons2.info, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _vehicle,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle number (optional)',
                prefixIcon: AppIcon(Icons2.vehicles, size: IconSize.inline),
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
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    color: Tokens.danger,
                  ),
                ),
              ),
            ],

            SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: _busy ? null : _submit,
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
                  : const Text('Send the request'),
            ),
            SizedBox(height: Tokens.space2),
            Text(
              'This asks the resident to approve. The visitor is not cleared until they do.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.45,
                color: Tokens.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _flatLabel(Map<String, dynamic> flat) {
    final label = flat['label'] ?? flat['flatLabel'] ?? flat['number'];
    if (label is String && label.trim().isNotEmpty) return label;
    final name = flat['residentName'] ?? flat['name'];
    if (name is String && name.trim().isNotEmpty) return name;
    return 'Flat ${flat['id'] ?? ''}';
  }

  String? _flatSub(Map<String, dynamic> flat) {
    final parts = <String>[
      if (flat['towerName'] is String) flat['towerName'] as String,
      if (flat['residentName'] is String) flat['residentName'] as String,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _ChosenFlat extends StatelessWidget {
  const _ChosenFlat({required this.flat, required this.onClear});
  final Map<String, dynamic> flat;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Tokens.accentTint,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AppIcon(Icons2.flat, size: IconSize.inline, color: Tokens.accent),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              '${flat['label'] ?? flat['flatLabel'] ?? 'Flat'} · resident notified',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w500,
                color: Tokens.accent,
              ),
            ),
          ),
          InkResponse(
            onTap: onClear,
            radius: 18,
            child: Padding(
              padding: EdgeInsets.all(Tokens.space1),
              child: AppIcon(
                Icons2.close,
                size: IconSize.inline,
                color: Tokens.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after the request is sent.
class _SentState extends StatelessWidget {
  const _SentState({required this.name, required this.onDone});
  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: kScreenBottomPadding),
      children: [
        SizedBox(height: Tokens.space6),
        AppIcon(Icons2.success, size: IconSize.empty, color: Tokens.accent),
        SizedBox(height: Tokens.space4),
        Text(
          'Request sent',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeLg,
            fontWeight: FontWeight.w600,
            color: Tokens.ink,
          ),
        ),
        SizedBox(height: Tokens.space2),
        Text(
          '$name is not cleared yet. The resident has been asked to approve, and the visitor '
          'waits at the gate until they answer.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeSm,
            height: 1.5,
            color: Tokens.inkMuted,
          ),
        ),
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: Tokens.accent,
            minimumSize: const Size.fromHeight(Tokens.controlHeight),
          ),
          child: const Text('Back to the gate'),
        ),
      ],
    );
  }
}
