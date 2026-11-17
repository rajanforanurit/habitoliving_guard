import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Register a courier at the gate.
///
/// Two fields are required: the flat the parcel is for, and the courier's
/// company. Everything else is optional. Registration notifies the resident,
/// who allows or refuses it — the result screen says so, so nobody is told a
/// parcel is inside before the resident has answered.
class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({super.key});

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _flatQuery = TextEditingController();
  final _courier = TextEditingController();
  final _note = TextEditingController();

  List<Map<String, dynamic>> _matches = [];
  Map<String, dynamic>? _flat;
  bool _searching = false;
  bool _busy = false;
  String? _error;

  String _type = 'PARCEL';

  static final _types = <(String, String)>[
    ('PARCEL', 'Parcel'),
    ('FOOD', 'Food'),
    ('GROCERY', 'Grocery'),
    ('DOCUMENT', 'Document'),
    ('OTHER', 'Other'),
  ];

  @override
  void dispose() {
    _flatQuery.dispose();
    _courier.dispose();
    _note.dispose();
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
      showMessage(context, 'Choose the flat this parcel is for.', error: true);
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.guard.registerDelivery(
        flatId: _flat!['id']?.toString() ?? '',
        courier: _courier.text.trim(),
        type: _type,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showMessage(
        context,
        'Registered. The resident has been asked to allow it.',
      );
      Navigator.of(context).pop(true);
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
    return AppScaffold(
      title: 'Register a delivery',
      subtitle: 'Courier at the gate',
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kScreenBottomPadding),
          children: [
            SectionLabel('For'),
            SizedBox(height: Tokens.space2),
            TextField(
              controller: _flatQuery,
              textInputAction: TextInputAction.search,
              onChanged: _search,
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
            SectionLabel('What it is'),
            SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final (value, label) in _types)
                  _Choice(
                    label: label,
                    selected: value == _type,
                    onTap: () => setState(() => _type = value),
                  ),
              ],
            ),

            SizedBox(height: Tokens.space5),
            SectionLabel('The courier'),
            SizedBox(height: Tokens.space2),
            TextFormField(
              controller: _courier,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Which company or person is delivering?'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Courier or company',
                prefixIcon: AppIcon(Icons2.deliveries, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note for the resident (optional)',
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
                  : const Text('Register and notify'),
            ),
            SizedBox(height: Tokens.space2),
            Text(
              'The resident decides. A refused delivery stays at the gate.',
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

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              fontWeight: FontWeight.w600,
              color: selected ? Tokens.accentOn : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
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
