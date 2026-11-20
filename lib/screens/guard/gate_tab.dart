import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/authed_image.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'visitor_register_screen.dart';
import 'verify_screen.dart';

/// The guard's today screen: the gate briefing.
///
/// Ordered the way a shift actually runs. The top card is the gate and the
/// count of things waiting on the guard; below that, the three queues that need
/// a decision (visitors awaiting approval, deliveries awaiting a decision,
/// active alerts); below that, who is expected today.
///
/// Nothing is invented: if no one is expected, the section says so.
class GateTab extends StatefulWidget {
  const GateTab({super.key});

  @override
  State<GateTab> createState() => _GateTabState();
}

class _GateTabState extends State<GateTab> {
  late Future<GuardDashboard> _dashboard;
  late Future<List<Visitor>> _pending;
  late Future<List<Visitor>> _active;
  late Future<List<Delivery>> _deliveries;
  late Future<List<EmergencyAlert>> _alerts;
  late Future<List<ExpectedHelper>> _helpers;

  final List<void Function()> _unsubscribers = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    // The resident's decision lands here the instant it is made. The queue
    // reloads and the guard sees a clear "allow / do not allow" banner, so they
    // never have to guess whether to open the gate.
    final socket = AppServices.instance.socket;
    _unsubscribers.add(socket.on(Events.visitorDecision, _onDecision));
    for (final e in const [
      Events.visitorArrived,
      Events.visitorEntered,
      Events.visitorExited,
      Events.visitorDenied,
      Events.visitorOverstay,
    ]) {
      _unsubscribers.add(socket.on(e, (_) {
        if (mounted) _refresh();
      }));
    }
  }

  @override
  void dispose() {
    for (final u in _unsubscribers) {
      u();
    }
    super.dispose();
  }

  var _lastDecision = '';

  void _onDecision(RealtimeEvent event) {
    if (!mounted) return;
    _refresh();
    final map = event.data;
    // The same decision can arrive twice (socket room + push fan-out); show once.
    final key = '${map['visitorId']}:${map['decision']}';
    if (key == _lastDecision) return;
    _lastDecision = key;
    final approved = '${map['decision']}'.toUpperCase() == 'APPROVE';
    final name = '${map['name'] ?? 'Visitor'}';
    final flat = '${map['flatLabel'] ?? 'the flat'}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? 'Approved — allow entry' : 'Declined — do not allow'),
        content: Text(
          approved
              ? '$flat approved $name. Record the entry when they walk in.'
              : '$flat declined $name. Do not let them in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _refresh() {
    final api = AppServices.instance.guard;
    _dashboard = api.dashboard();
    _pending = api.pendingVisitors();
    _active = api.activeVisitors();
    _deliveries = api.deliveries(limit: 10).then((p) => p.items);
    _alerts = api.activeAlerts();
    _helpers = api.expectedHelpers();
    if (mounted) setState(() {});
  }

  Future<void> _pull() async {
    _refresh();
    // Await everything so the spinner reflects the slowest call, and surface a
    // failure instead of a half-loaded screen.
    try {
      await Future.wait([
        _dashboard,
        _pending,
        _active,
        _deliveries,
        _alerts,
        _helpers,
      ]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gate',
      subtitle: 'Today at the gate',
      onRefresh: _pull,
      actions: [
        HeaderAction(
          icon: Icons2.scan,
          tooltip: 'Verify a pass',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const VerifyScreen())),
        ),
      ],
      body: FutureBuilder<GuardDashboard>(
        future: _dashboard,
        builder: (context, dash) {
          if (dash.connectionState == ConnectionState.waiting) {
            return const LoadingPage();
          }
          if (dash.hasError) {
            return ErrorState(message: '${dash.error}', onRetry: _pull);
          }
          final d = dash.data ?? GuardDashboard.empty;
          return ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: [
              _BriefingCard(dashboard: d),
              const SizedBox(height: Tokens.space5),

              const SectionLabel('Waiting on you'),
              const SizedBox(height: Tokens.space2),
              _QueuePanel(
                pending: _pending,
                active: _active,
                deliveries: _deliveries,
                alerts: _alerts,
                onRefresh: _pull,
                onRegisterVisitor: () => _openRegister(context),
              ),
              const SizedBox(height: Tokens.space5),

              const SectionLabel('Expected today'),
              const SizedBox(height: Tokens.space2),
              _HelpersList(future: _helpers),
              const SizedBox(height: Tokens.space6),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRegister(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VisitorRegisterScreen()),
    );
    if (created == true) _pull();
  }
}

/// The gate card: where the guard is posted, and what is queued.
class _BriefingCard extends StatelessWidget {
  const _BriefingCard({required this.dashboard});
  final GuardDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final busy = dashboard.hasWork;
    return Container(
      padding: EdgeInsets.all(Tokens.space5),
      decoration: BoxDecoration(
        color: busy ? Tokens.dangerTint : Tokens.accentTint,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: busy ? Tokens.danger.withValues(alpha: 0.28) : Tokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                busy ? Icons2.warning : Icons2.gate,
                size: IconSize.header,
                color: busy ? Tokens.danger : Tokens.accent,
              ),
              SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  busy ? 'Needs a decision' : 'Gate briefing',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeMd,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Tokens.space2),
          Text(
            busy
                ? 'Something at this gate needs a decision before the queue grows.'
                : 'Nothing is waiting at the gate. Walk-ins and verifications appear here.',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              height: 1.45,
              color: Tokens.inkMuted,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Row(
            children: [
              _Metric(
                value: dashboard.pendingVisitors,
                label: 'Awaiting',
                alert: dashboard.pendingVisitors > 0,
              ),
              _Metric(value: dashboard.activeVisitors, label: 'Inside'),
              _Metric(value: dashboard.expectedVisitors, label: 'Expected'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.alert = false});

  final int value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: Tokens.typeXl,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: alert ? Tokens.danger : Tokens.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four live queues, each a Future so one slow call does not blank the rest.
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.pending,
    required this.active,
    required this.deliveries,
    required this.alerts,
    required this.onRefresh,
    required this.onRegisterVisitor,
  });

  final Future<List<Visitor>> pending;
  final Future<List<Visitor>> active;
  final Future<List<Delivery>> deliveries;
  final Future<List<EmergencyAlert>> alerts;
  final Future<void> Function() onRefresh;
  final VoidCallback onRegisterVisitor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QueueCard<Visitor>(
          icon: Icons2.visitors,
          title: 'Visitors awaiting approval',
          emptyTitle: 'Nobody is waiting for approval',
          emptyMessage:
              'A walk-in registration lands here until the resident decides.',
          future: pending,
          itemBuilder: (v) => ListRow(
            title: v.name,
            subtitle: [
              if (v.flatLabel != null) v.flatLabel!,
              if (v.company != null) v.company!,
              if (v.purpose != null) v.purpose!,
            ].join(' · '),
            leading: v.photoFileId != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    child: AuthedImage(
                      fileId: v.photoFileId!,
                      width: 40,
                      height: 40,
                    ),
                  )
                : const AppIcon(Icons2.visitors, size: IconSize.row),
            onTap: () => _openVisitor(context, v),
          ),
        ),
        const SizedBox(height: Tokens.space3),
        _QueueCard<Visitor>(
          icon: Icons2.gate,
          title: 'Already inside',
          emptyTitle: 'The society is empty',
          emptyMessage:
              'Visitors cleared to enter show up here until they leave.',
          future: active,
          itemBuilder: (v) => ListRow(
            title: v.name,
            subtitle: [
              if (v.flatLabel != null) v.flatLabel!,
              if (v.checkedInAt != null) 'in at ${Fmt.time(v.checkedInAt)}',
            ].join(' · '),
            leading: const AppIcon(Icons2.gate, size: IconSize.row),
            trailing: const MetaTag('Inside'),
            onTap: () => _openVisitor(context, v),
          ),
        ),
        const SizedBox(height: Tokens.space3),
        _QueueCard<Delivery>(
          icon: Icons2.deliveries,
          title: 'Deliveries awaiting a decision',
          emptyTitle: 'No parcels waiting',
          emptyMessage:
              'Courier registrations appear here for the resident to allow or refuse.',
          future: deliveries,
          itemBuilder: (d) => ListRow(
            title: d.courier ?? 'Delivery',
            subtitle: [
              if (d.flatLabel != null) d.flatLabel!,
              if (d.type != null) d.type!,
              if (d.arrivedAt != null) Fmt.relative(d.arrivedAt),
            ].join(' · '),
            leading: const AppIcon(Icons2.deliveries, size: IconSize.row),
            trailing: d.isWaiting ? const MetaTag('Waiting') : null,
          ),
        ),
        const SizedBox(height: Tokens.space3),
        _QueueCard<EmergencyAlert>(
          icon: Icons2.incidents,
          title: 'Active alerts',
          emptyTitle: 'No active alerts',
          emptyMessage:
              'Panic alerts raised in the society appear here until resolved.',
          future: alerts,
          itemBuilder: (a) => ListRow(
            title: a.type,
            subtitle: [
              if (a.flatLabel != null) a.flatLabel!,
              if (a.location != null) a.location!,
              if (a.createdAt != null) Fmt.relative(a.createdAt),
            ].join(' · '),
            leading: AppIcon(
              Icons2.incidents,
              size: IconSize.row,
              color: Tokens.danger,
            ),
            trailing: StatusBadge.forStatus(a.status),
          ),
        ),
      ],
    );
  }

  Future<void> _openVisitor(BuildContext context, Visitor v) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VisitorActions(visitor: v, onChanged: onRefresh),
    );
  }
}

/// A queue section that loads independently.
class _QueueCard<T> extends StatelessWidget {
  const _QueueCard({
    required this.icon,
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.future,
    required this.itemBuilder,
  });

  final IconData icon;
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final Future<List<T>> future;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.space4,
              Tokens.space3,
              Tokens.space4,
              Tokens.space2,
            ),
            child: Row(
              children: [
                AppIcon(icon, size: IconSize.inline, color: Tokens.inkMuted),
                SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<T>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(Tokens.space4),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Tokens.surfaceSunken,
                    color: Tokens.accent,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.all(Tokens.space4),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.danger,
                    ),
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    Tokens.space4,
                    Tokens.space2,
                    Tokens.space4,
                    Tokens.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emptyTitle,
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeSm,
                          fontWeight: FontWeight.w500,
                          color: Tokens.inkMuted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        emptyMessage,
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeXs,
                          height: 1.45,
                          color: Tokens.inkFaint,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Hairline(indent: Tokens.space4),
                    itemBuilder(items[i]),
                  ],
                  const SizedBox(height: Tokens.space2),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The action sheet for one visitor at the gate.
class _VisitorActions extends StatelessWidget {
  const _VisitorActions({required this.visitor, required this.onChanged});

  final Visitor visitor;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final guard = AppServices.instance.guard;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visitor.photoFileId != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                child: AuthedImage(
                  fileId: visitor.photoFileId!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: Tokens.space4),
            ],
            Text(
              visitor.name,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeLg,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
            SizedBox(height: Tokens.space1),
            Text(
              [
                if (visitor.flatLabel != null) visitor.flatLabel!,
                if (visitor.company != null) visitor.company!,
                if (visitor.phone != null) Fmt.phone(visitor.phone),
                visitor.type,
              ].join(' · '),
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                color: Tokens.inkMuted,
              ),
            ),
            if (visitor.passCode != null) ...[
              const SizedBox(height: Tokens.space3),
              _PassRow(code: visitor.passCode!),
            ],
            SizedBox(height: Tokens.space5),
            if (visitor.status == VisitorStatusValue.pendingApproval) ...[
              FilledButton(
                onPressed: () => _act(
                  context,
                  () => guard.requestApproval(visitor.id),
                  'The resident has been asked again.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Re-notify the resident'),
              ),
              const SizedBox(height: Tokens.space2),
            ],
            if (visitor.status == VisitorStatusValue.approved ||
                visitor.status == VisitorStatusValue.expected) ...[
              FilledButton(
                onPressed: () => _act(
                  context,
                  () => guard.recordEntry(visitor.id),
                  'Entry recorded.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Record entry'),
              ),
              const SizedBox(height: Tokens.space2),
            ],
            if (visitor.status == VisitorStatusValue.checkedIn) ...[
              FilledButton(
                onPressed: () => _act(
                  context,
                  () => guard.recordExit(visitor.id),
                  'Exit recorded.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Record exit'),
              ),
              const SizedBox(height: Tokens.space2),
            ],
            if (visitor.status != VisitorStatusValue.rejected &&
                visitor.status != VisitorStatusValue.checkedOut &&
                visitor.status != VisitorStatusValue.cancelled) ...[
              OutlinedButton(
                onPressed: () => _deny(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.danger,
                  side: BorderSide(color: Tokens.danger),
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Deny entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    Future<void> Function() action,
    String ok,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showMessage(context, ok);
      await onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _deny(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonDialog(
        title: 'Deny entry',
        hint: 'Why is entry being refused?',
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await AppServices.instance.guard.denyEntry(visitor.id, reason: reason);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'Entry denied.');
      await onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }
}

class _PassRow extends StatelessWidget {
  const _PassRow({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pass',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
          SizedBox(width: Tokens.space2),
          Text(
            code,
            style: TextStyle(
              fontFamily: Tokens.fontMono,
              fontSize: Tokens.typeMd,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: Tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reason prompt used by deny and refuse. Returns null when dismissed.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
        maxLines: 3,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

/// The helpers expected at the gate today.
class _HelpersList extends StatelessWidget {
  const _HelpersList({required this.future});
  final Future<List<ExpectedHelper>> future;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: FutureBuilder<List<ExpectedHelper>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(Tokens.space4),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Tokens.surfaceSunken,
                color: Tokens.accent,
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: EdgeInsets.all(Tokens.space4),
              child: Text(
                '${snapshot.error}',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.danger,
                ),
              ),
            );
          }
          final helpers = snapshot.data ?? const [];
          if (helpers.isEmpty) {
            return const EmptyState(
              compact: true,
              icon: Icons2.staff,
              title: 'No helpers expected today',
              message: 'Domestic staff cleared for this society appear here.',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < helpers.length; i++) ...[
                if (i > 0) const Hairline(indent: Tokens.space4),
                ListRow(
                  title: helpers[i].name,
                  subtitle: [
                    helpers[i].type,
                    if (helpers[i].flatLabel != null) helpers[i].flatLabel!,
                    if (helpers[i].expectedAt != null)
                      Fmt.time(helpers[i].expectedAt),
                  ].join(' · '),
                  leading: const AppIcon(Icons2.staff, size: IconSize.row),
                  trailing: helpers[i].checkedIn
                      ? const StatusBadge(label: 'Checked in')
                      : const MetaTag('Expected'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
