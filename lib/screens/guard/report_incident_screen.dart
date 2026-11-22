import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Report an incident for the shift log.
///
/// Four fields, in the order a report is actually dictated over a radio: what
/// happened, where, how much detail is needed, and that is it. The guard's name
/// is taken from the session — the backend attaches it, so the form does not ask.
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _location = TextEditingController();

  String _type = 'OTHER';
  bool _busy = false;
  String? _error;

  static final _types = <(String, String)>[
    ('SUSPICIOUS_ACTIVITY', 'Suspicious activity'),
    ('THEFT', 'Theft'),
    ('ALTERCATION', 'Altercation'),
    ('TRESPASS', 'Unauthorised entry'),
    ('DAMAGE', 'Damage'),
    ('OTHER', 'Other'),
  ];

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.guard.reportIncident(
        type: _type,
        description: _description.text.trim(),
        location: _location.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Logged. The next shift will see it.');
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
      title: 'Report an incident',
      subtitle: 'For the shift log',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.all(Tokens.space4),
          children: [
            SectionLabel('What happened'),
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
            SectionLabel('Where'),
            SizedBox(height: Tokens.space2),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Block, floor, gate or flat',
                prefixIcon: AppIcon(Icons2.flat, size: IconSize.inline),
              ),
            ),

            SizedBox(height: Tokens.space5),
            SectionLabel('What you saw'),
            SizedBox(height: Tokens.space2),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'A sentence or two so the next shift understands it'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Details',
                alignLabelWithHint: true,
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
                  : const Text('Log it'),
            ),
          ],
        ),
      ),
    );
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
