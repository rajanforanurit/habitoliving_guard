import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../app.dart';

/// Society emergency contacts, the guard's incident reports and alert action.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  late Future<void> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    final api = AppServices.instance.guard;
    final results = await Future.wait([
      api.emergencyContacts(),
      api.incidents(limit: 5),
    ]);
    if (!mounted) return;
    setState(() {
      _contacts = results[0] as List<EmergencyContact>;
      _incidents = results[1] as PageResult<Incident>;
    });
  }

  List<EmergencyContact> _contacts = const [];
  PageResult<Incident>? _incidents;
  bool _alerting = false;

  Future<void> _refresh() async {
    setState(() => _load = _fetch());
    try {
      await _load;
    } catch (_) {
      // The FutureBuilder presents the error and retry action.
    }
  }

  Future<void> _call(EmergencyContact contact) async {
    final number = (contact.phone ?? '').trim();
    if (number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showMessage(context, 'Could not open the phone dialer.', error: true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Could not start the call: $e', error: true);
      }
    }
  }

  Future<void> _panic() async {
    final ok = await confirmDialog(
      context,
      title: 'Raise a panic alert?',
      message:
          'The society admin and other guards are alerted immediately. '
          'Use this when you need help now.',
      confirmLabel: 'Send alert',
    );
    if (ok != true || !mounted || _alerting) return;
    setState(() => _alerting = true);
    try {
      await AppServices.instance.guard.raiseAlert(
        type: 'SECURITY',
        message: 'Panic alert raised by the guard',
      );
      if (mounted) {
        showMessage(context, 'Alert sent to the admin and other guards.');
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _alerting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Emergency',
      subtitle: AppServices.instance.session.societyName,
      showBack: true,
      onRefresh: _refresh,
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _contacts.isEmpty &&
              _incidents == null) {
            return const LoadingPage();
          }
          if (snapshot.hasError && _contacts.isEmpty && _incidents == null) {
            return ErrorState(message: '${snapshot.error}', onRetry: _refresh);
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: Tokens.gutter,
              right: Tokens.gutter,
              bottom: kScreenBottomPadding,
            ),
            children: [
              _PanicCard(onPressed: _alerting ? null : _panic),
              const SectionLabel('Call now'),
              const SizedBox(height: Tokens.space2),
              if (_contacts.isEmpty)
                const EmptyState(
                  icon: Icons2.phone,
                  title: 'No contacts published',
                  message:
                      'Your society has not added security or helpline '
                      'numbers yet.',
                  compact: true,
                )
              else
                Column(
                  children: [
                    for (final c in _contacts) ...[
                      _ContactTile(contact: c, onCall: _call),
                      if (c != _contacts.last) const Hairline(),
                    ],
                  ],
                ),
              if (_incidents != null && _incidents!.items.isNotEmpty) ...[
                const SectionLabel('Recent incidents'),
                const SizedBox(height: Tokens.space2),
                for (final i in _incidents!.items) ...[
                  ListRow(
                    title: i.type,
                    subtitle: i.description ?? i.location,
                    leading: const AppIcon(
                      Icons2.incidents,
                      size: IconSize.row,
                    ),
                    trailing: StatusBadge.forStatus(
                      i.status,
                      domain: StatusDomain.incident,
                    ),
                  ),
                  const Hairline(),
                ],
              ],
              const SizedBox(height: Tokens.space6),
            ],
          );
        },
      ),
    );
  }
}

/// The panic button. Full width, danger colour, no icon that looks friendly.
class _PanicCard extends StatelessWidget {
  const _PanicCard({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space6),
      child: SizedBox(
        height: 64,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Tokens.danger,
            // White glyph and white label: the dark ink colour was nearly
            // invisible against the dark red fill.
            foregroundColor: Tokens.accentOn,
          ),
          icon: AppIcon(
            Icons2.emergency,
            size: IconSize.header,
            color: Tokens.accentOn,
          ),
          label: Text(
            'Panic alert',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeMd,
              fontWeight: FontWeight.w600,
              color: Tokens.accentOn,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onCall});
  final EmergencyContact contact;
  final ValueChanged<EmergencyContact> onCall;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: contact.name,
      subtitle: [contact.category, contact.phone].join(' · '),
      icon: Icons2.phone,
      onTap: () => onCall(contact),
      trailing: const AppIcon(Icons2.external, size: IconSize.inline),
    );
  }
}
