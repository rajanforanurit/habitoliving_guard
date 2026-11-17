import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/paged_list.dart';
import 'delivery_register_screen.dart';

/// The guard's delivery desk.
///
/// Three things happen to a parcel: it is registered at the gate, the resident
/// allows or refuses it, and it either goes in or stays at the gate for
/// collection. This screen is the middle of that flow, so each row carries the
/// action that is legal for its status rather than a menu of everything.
class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key});

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab> {
  /// Server-side filter. An empty string means "everything".
  String _status = '';

  static const _filters = <(String, String)>[
    ('', 'All'),
    ('PENDING_APPROVAL', 'Waiting'),
    ('APPROVED', 'Approved'),
    ('LEFT_AT_GATE', 'At gate'),
    ('COLLECTED', 'Collected'),
    ('ENTERED', 'Inside'),
    ('EXITED', 'Exited'),
  ];

  int _tick = 0;

  void _setStatus(String value) {
    if (value == _status) return;
    setState(() {
      _status = value;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final guard = AppServices.instance.guard;
    return AppScaffold(
      title: 'Deliveries',
      subtitle: 'Gate register',
      floatingAction: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const DeliveryRegisterScreen()),
          );
          if (created == true) setState(() => _tick++);
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.row),
        label: const Text(
          'Register',
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space4,
              Tokens.space3,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (value, label) in _filters) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: Tokens.space2),
                      child: _Chip(
                        label: label,
                        selected: value == _status,
                        onTap: () => _setStatus(value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: PagedList<Delivery>(
              // Keyed on the filter and the refresh tick, so a new filter
              // refetches from page 1 instead of appending.
              key: ValueKey('$_status-$_tick'),
              fetch: (page) => guard.deliveries(
                page: page,
                limit: 20,
                status: _status.isEmpty ? null : _status,
              ),
              emptyIcon: Icons2.deliveries,
              emptyTitle: _status.isEmpty
                  ? 'No deliveries at the gate'
                  : 'Nothing in this state',
              emptyMessage: _status.isEmpty
                  ? 'Register a courier when one arrives, then the resident decides.'
                  : 'Switch the filter to see the rest of the register.',
              itemBuilder: (context, d, _) => _DeliveryRow(
                delivery: d,
                onAction: () => setState(() => _tick++),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

/// One row of the register, with the action its status allows.
class _DeliveryRow extends StatefulWidget {
  const _DeliveryRow({required this.delivery, required this.onAction});
  final Delivery delivery;
  final VoidCallback onAction;

  @override
  State<_DeliveryRow> createState() => _DeliveryRowState();
}

class _DeliveryRowState extends State<_DeliveryRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, ok);
      widget.onAction();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handOver() async {
    final otp = await _promptFor(
      title: 'Hand over the parcel',
      hint: 'Collection OTP from the resident',
      confirm: 'Hand over',
    );
    if (otp == null || otp.trim().isEmpty) return;
    await _run(
      () => AppServices.instance.guard.handOver(
        widget.delivery.id,
        otp: otp.trim(),
      ),
      'Handed over.',
    );
  }

  Future<void> _deny() async {
    final reason = await _promptFor(
      title: 'Refuse the delivery',
      hint: 'Why is it refused?',
      confirm: 'Refuse',
      destructive: true,
    );
    if (reason == null) return;
    await _run(
      () => AppServices.instance.guard.denyEntry(
        widget.delivery.id,
        reason: reason.isEmpty ? null : reason,
      ),
      'Refused.',
    );
  }

  Future<String?> _promptFor({
    required String title,
    required String hint,
    required String confirm,
    bool destructive = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _Prompt(
        title: title,
        hint: hint,
        confirm: confirm,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final waiting = d.isWaiting;
    return Container(
      color: Tokens.surface,
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.courier ?? 'Delivery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              StatusBadge.forStatus(
                d.status.name,
                domain: StatusDomain.delivery,
              ),
            ],
          ),
          SizedBox(height: Tokens.space1),
          Text(
            [
              if (d.flatLabel != null) d.flatLabel!,
              if (d.type != null) d.type!,
              if (d.arrivedAt != null) Fmt.relative(d.arrivedAt),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
          if (d.note != null) ...[
            SizedBox(height: Tokens.space2),
            Text(
              d.note!,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.4,
                color: Tokens.inkMuted,
              ),
            ),
          ],
          SizedBox(height: Tokens.space3),
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Tokens.surfaceSunken,
              color: Tokens.accent,
            )
          else
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                // A waiting parcel can be allowed in, or left at the gate.
                if (waiting) ...[
                  _Action(
                    label: 'Allow entry',
                    icon: Icons2.success,
                    onTap: () => _run(
                      () => AppServices.instance.guard.requestDeliveryApproval(
                        d.id,
                      ),
                      'The resident has been asked again.',
                    ),
                  ),
                  _Action(
                    label: 'Leave at gate',
                    icon: Icons2.gate,
                    onTap: () => _run(
                      () => AppServices.instance.guard.leaveAtGate(d.id),
                      'Kept at the gate. The resident needs the OTP to collect.',
                    ),
                  ),
                ],
                if (d.status == DeliveryStatusValue.approved) ...[
                  _Action(
                    label: 'Record entry',
                    icon: Icons2.gate,
                    onTap: () => _run(
                      () =>
                          AppServices.instance.guard.recordDeliveryEntry(d.id),
                      'Entry recorded.',
                    ),
                  ),
                ],
                if (d.status == DeliveryStatusValue.leftAtGate)
                  _Action(
                    label: 'Hand over',
                    icon: Icons2.deliveries,
                    onTap: _handOver,
                  ),
                if (d.status == DeliveryStatusValue.entered)
                  _Action(
                    label: 'Record exit',
                    icon: Icons2.forward,
                    onTap: () => _run(
                      () => AppServices.instance.guard.recordDeliveryExit(d.id),
                      'Exit recorded.',
                    ),
                  ),
                if (waiting ||
                    d.status == DeliveryStatusValue.approved ||
                    d.status == DeliveryStatusValue.entered)
                  _Action(
                    label: 'Refuse',
                    icon: Icons2.close,
                    destructive: true,
                    onTap: _deny,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Tokens.danger : Tokens.accent;
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: color),
              const SizedBox(width: Tokens.space1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared text prompt used by the row actions.
class _Prompt extends StatefulWidget {
  const _Prompt({
    required this.title,
    required this.hint,
    required this.confirm,
    this.destructive = false,
  });

  final String title;
  final String hint;
  final String confirm;
  final bool destructive;

  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive ? Tokens.danger : Tokens.accent,
          ),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
