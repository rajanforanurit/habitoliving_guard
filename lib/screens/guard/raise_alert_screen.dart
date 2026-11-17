import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Raise an alert to the admin and to every other guard on duty.
///
/// Three types, because those are the ones a guard acts on alone: fire, medical
/// and security. Anything else is an incident (see the incident log), which does
/// not page anyone.
///
/// The form asks for a location and a message and nothing else. In an emergency
/// the guard should not be typing.
class RaiseAlertScreen extends StatefulWidget {
  const RaiseAlertScreen({super.key});

  @override
  State<RaiseAlertScreen> createState() => _RaiseAlertScreenState();
}

class _RaiseAlertScreenState extends State<RaiseAlertScreen> {
  final _location = TextEditingController();
  final _message = TextEditingController();

  String _type = 'FIRE';
  bool _busy = false;
  String? _error;

  static final _types = <(String, String, IconData)>[
    ('FIRE', 'Fire', Icons2.warning),
    ('MEDICAL', 'Medical', Icons2.incidents),
    ('SECURITY', 'Security', Icons2.security),
  ];

  @override
  void dispose() {
    _location.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.guard.raiseAlert(
        type: _type,
        location: _location.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      showMessage(
        context,
        'Alert raised. The admin and other guards are notified.',
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
      title: 'Raise an alert',
      subtitle: 'Notifies the admin and the other guards',
      body: ListView(
        padding: EdgeInsets.only(
          left: Tokens.gutter,
          right: Tokens.gutter,
          bottom: kScreenBottomPadding,
        ),
        children: [
          Text(
            'Only raise this if you cannot handle it alone. A fire, a medical '
            'emergency or a security threat all qualify.',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              height: 1.5,
              color: Tokens.inkMuted,
            ),
          ),
          SizedBox(height: Tokens.space5),
          SectionLabel('Type'),
          SizedBox(height: Tokens.space2),
          for (final (value, label, icon) in _types) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: _TypeTile(
                label: label,
                icon: icon,
                selected: value == _type,
                onTap: () => setState(() => _type = value),
              ),
            ),
          ],

          SizedBox(height: Tokens.space3),
          SectionLabel('Where'),
          SizedBox(height: Tokens.space2),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Block, floor, gate or flat',
              prefixIcon: AppIcon(Icons2.flat, size: IconSize.inline),
            ),
          ),

          SizedBox(height: Tokens.space4),
          SectionLabel('What is happening'),
          SizedBox(height: Tokens.space2),
          TextField(
            controller: _message,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'One or two sentences',
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
              backgroundColor: Tokens.danger,
              foregroundColor: Tokens.accentOn,
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
                : const Text('Raise the alert'),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Tokens.danger : Tokens.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 12,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space3,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.dangerTint : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(
              color: selected
                  ? Tokens.danger.withValues(alpha: 0.4)
                  : Tokens.line,
            ),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: IconSize.row, color: color),
              SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Tokens.danger : Tokens.ink,
                  ),
                ),
              ),
              if (selected)
                AppIcon(
                  Icons2.success,
                  size: IconSize.inline,
                  color: Tokens.danger,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
