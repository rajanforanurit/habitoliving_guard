import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'report_incident_screen.dart';
import 'raise_alert_screen.dart';

/// Alerts: what is happening right now that needs a guard.
///
/// Two sources, kept apart because they are handled differently:
///   Panic alerts — raised by a resident in trouble. A guard acknowledges, then
///     resolves. These are ordered by time, newest first, because the newest
///     panic is the most likely to still be live.
///   Incidents — something the guard logged. Reported, then resolved by an
///     admin or the guard.
///
/// An alert card is deliberately loud: an active alert is a red-tinted panel,
/// not a row in a list, because a missed panic is the worst failure this screen
/// can have.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  late Future<List<EmergencyAlert>> _alerts;
  late Future<GuardDashboard> _dashboard;
  int _tick = 0;

  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _alerts = AppServices.instance.guard.activeAlerts();
    _dashboard = AppServices.instance.guard.dashboard();
    // The moment a panic is raised anywhere in the society, the list is at
    // most one frame behind — not one pull behind.
    _unsubscribe = AppServices.instance.socket.on(
      Events.emergencyAlert,
      (_) => _pull(),
    );
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _reload() {
    _alerts = AppServices.instance.guard.activeAlerts();
    _dashboard = AppServices.instance.guard.dashboard();
    setState(() => _tick++);
  }

  Future<void> _pull() async {
    _reload();
    try {
      await Future.wait([_alerts, _dashboard]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Alerts',
      subtitle: 'Panic alerts and today at the gate',
      onRefresh: _pull,
      floatingAction: FloatingActionButton.extended(
        onPressed: () async {
          final raised = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RaiseAlertScreen()),
          );
          if (raised == true) _pull();
        },
        backgroundColor: Tokens.danger,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.row),
        label: const Text(
          'Raise alert',
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _pull,
        color: Tokens.accent,
        child: ListView(
          padding: EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Panic alerts',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  Text(
                    'Newest first',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            _AlertList(future: _alerts, onChanged: _pull),
            SizedBox(height: Tokens.space6),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today at the gate',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  InkResponse(
                    onTap: () async {
                      final logged = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const ReportIncidentScreen(),
                        ),
                      );
                      if (logged == true) _pull();
                    },
                    radius: 16,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Tokens.space1,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            Icons2.add,
                            size: IconSize.inline,
                            color: Tokens.accent,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Report',
                            style: TextStyle(
                              fontFamily: Tokens.fontFamily,
                              fontSize: Tokens.typeXs,
                              fontWeight: FontWeight.w600,
                              color: Tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _TodayPanel(future: _dashboard, tick: _tick),
          ],
        ),
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.future, required this.onChanged});
  final Future<List<EmergencyAlert>> future;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmergencyAlert>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: Tokens.space5),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Tokens.surfaceSunken,
              color: Tokens.accent,
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space4,
              vertical: Tokens.space4,
            ),
            child: ErrorState(compact: true, message: '${snapshot.error}'),
          );
        }
        final alerts = snapshot.data ?? const [];
        if (alerts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: EmptyState(
              compact: true,
              icon: Icons2.success,
              title: 'No active alerts',
              message:
                  'A panic raised in the society appears here until someone resolves it.',
            ),
          );
        }
        return Column(
          children: [
            for (final a in alerts) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: _AlertCard(alert: a, onChanged: onChanged),
              ),
              const SizedBox(height: Tokens.space3),
            ],
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatefulWidget {
  const _AlertCard({required this.alert, required this.onChanged});
  final EmergencyAlert alert;
  final Future<void> Function() onChanged;

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, ok);
      await widget.onChanged();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final guard = AppServices.instance.guard;
    final live = a.isActive;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: live ? Tokens.dangerTint : Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: live ? Tokens.danger.withValues(alpha: 0.3) : Tokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                live ? Icons2.incidents : Icons2.success,
                size: IconSize.row,
                color: live ? Tokens.danger : Tokens.inkMuted,
              ),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  a.type,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w700,
                    color: live ? Tokens.danger : Tokens.ink,
                  ),
                ),
              ),
              StatusBadge(label: a.status),
            ],
          ),
          if (a.message != null) ...[
            SizedBox(height: Tokens.space2),
            Text(
              a.message!,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                height: 1.45,
                color: Tokens.ink,
              ),
            ),
          ],
          SizedBox(height: Tokens.space2),
          Text(
            [
              if (a.flatLabel != null) a.flatLabel!,
              if (a.location != null) a.location!,
              if (a.raisedBy != null) 'raised by ${a.raisedBy}',
              if (a.createdAt != null) Fmt.relative(a.createdAt),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              height: 1.4,
              color: Tokens.inkFaint,
            ),
          ),
          if (_busy) ...[
            SizedBox(height: Tokens.space3),
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Tokens.surfaceSunken,
              color: Tokens.accent,
            ),
          ] else ...[
            const SizedBox(height: Tokens.space3),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                if (live)
                  _Action(
                    label: 'Acknowledge',
                    icon: Icons2.success,
                    onTap: () => _run(
                      () => guard.updateAlert(a.id, status: 'ACKNOWLEDGED'),
                      'Acknowledged. The resident can see it is being handled.',
                    ),
                  ),
                if (live || a.acknowledgedAt != null)
                  _Action(
                    label: 'Resolve',
                    icon: Icons2.success,
                    onTap: () => _run(
                      () => guard.updateAlert(a.id, status: 'RESOLVED'),
                      'Resolved.',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: Tokens.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: Tokens.inkMuted),
              SizedBox(width: Tokens.space1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: Tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.future, required this.tick});
  final Future<GuardDashboard> future;
  final int tick;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuardDashboard>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: Tokens.space5),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Tokens.surfaceSunken,
              color: Tokens.accent,
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space4,
              vertical: Tokens.space4,
            ),
            child: ErrorState(compact: true, message: '${snapshot.error}'),
          );
        }
        final d = snapshot.data ?? GuardDashboard.empty;
        final recent = d.recentActivity.take(6).toList();
        return Panel(
          margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Count(value: '${d.todayVisitors}', label: 'Visitors today'),
                  const _Divider(),
                  _Count(value: '${d.todayDeliveries}', label: 'Deliveries'),
                  const _Divider(),
                  _Count(
                    value: '${d.domesticHelpPresent}',
                    label: 'Domestic help',
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                Hairline(),
                SizedBox(height: Tokens.space2),
                Text(
                  'RECENT MOVEMENT',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Tokens.inkFaint,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: Tokens.space1),
                for (var i = 0; i < recent.length; i++)
                  _RecentRow(row: recent[i], first: i == 0),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: Tokens.typeLg,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: Tokens.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              height: 1.3,
              color: Tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Tokens.line);
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.row, required this.first});
  final Map<String, dynamic> row;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final name = row['name'] is String ? row['name'] as String : 'Visit';
    final flat = row['flatLabel'];
    final status = row['status'];
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : Tokens.space2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [name, if (flat is String && flat.isNotEmpty) flat].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                color: Tokens.ink,
              ),
            ),
          ),
          if (status is String && status.isNotEmpty)
            StatusBadge.forStatus(
              status,
              domain: StatusDomain.visitor,
              dot: false,
            ),
        ],
      ),
    );
  }
}
