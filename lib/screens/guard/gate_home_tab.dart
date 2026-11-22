import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'gate_flows.dart';
import 'gate_home_screen.dart';
import 'raise_alert_screen.dart';
import 'tower_flat_selector.dart';
import '../settings_screen.dart';

/// The Gate tab's live content.
///
/// The screen in `gate_home_screen.dart` is deliberately stateless: it renders
/// the values it is given. This widget owns the live data — the dashboard
/// counts, the guard identity, and the socket subscriptions that keep them
/// fresh while the guard is on shift.
class GateHomeTab extends StatefulWidget {
  const GateHomeTab({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.refreshTick,
  });

  final GateTab selectedTab;
  final ValueChanged<GateTab> onTabSelected;

  /// Bumped by the shell whenever a flow (register visitor/delivery, verify)
  /// finishes, so the counts reload without a manual pull.
  final ValueNotifier<int> refreshTick;

  @override
  State<GateHomeTab> createState() => _GateHomeTabState();
}

class _GateHomeTabState extends State<GateHomeTab> {
  late Future<GuardDashboard> _dashboard;
  String? _lastDecision;
  final List<void Function()> _unsubscribers = [];

  @override
  void initState() {
    super.initState();
    AppServices.instance.session.addListener(_onSession);
    widget.refreshTick.addListener(_onRefreshTick);
    _reload();
    _subscribe();
  }

  @override
  void dispose() {
    AppServices.instance.session.removeListener(_onSession);
    widget.refreshTick.removeListener(_onRefreshTick);
    for (final unsubscribe in _unsubscribers) {
      unsubscribe();
    }
    super.dispose();
  }

  void _onSession() {
    GateDirectory.clear();
    if (mounted) _reload();
  }

  void _onRefreshTick() {
    if (mounted) _reload();
  }

  void _subscribe() {
    final socket = AppServices.instance.socket;
    _unsubscribers.add(socket.on(Events.visitorDecision, _onDecision));
    for (final event in const [
      Events.visitorArrived,
      Events.visitorEntered,
      Events.visitorExited,
      Events.visitorDenied,
      Events.visitorOverstay,
      Events.deliveryArrived,
      Events.deliveryDecision,
      Events.emergencyAlert,
      Events.emergencyUpdated,
      Events.propertyInfoChanged,
    ]) {
      _unsubscribers.add(
        socket.on(event, (realtime) {
          if (realtime.name == Events.propertyInfoChanged) {
            GateDirectory.clear();
          }
          if (mounted) _reload();
        }),
      );
    }
  }

  // The same resident decision can arrive through more than one socket room.
  void _onDecision(RealtimeEvent event) {
    if (!mounted) return;
    final data = event.data;
    final key = "${data['visitorId']}:${data['decision']}";
    if (key == _lastDecision) return;
    _lastDecision = key;
    _reload();
    final approved = "${data['decision']}".toUpperCase() == 'APPROVE';
    final name = "${data['name'] ?? 'Visitor'}";
    final flat = "${data['flatLabel'] ?? 'The flat'}";
    final title = approved
        ? 'Approved — allow entry'
        : 'Declined — do not allow';
    final message = approved
        ? '$flat approved $name. Record the entry when they walk in.'
        : '$flat declined $name. Do not let them in.';

    // Keep the camera and registration routes above the gate free of dialogs.
    if (ModalRoute.of(context)?.isCurrent != true) {
      showMessage(context, message);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _reload() {
    _dashboard = AppServices.instance.guard.dashboard();
    if (mounted) setState(() {});
  }

  Future<void> _pull() async {
    GateDirectory.clear();
    _reload();
    try {
      await _dashboard;
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  void _changed() {
    _reload();
  }

  Future<void> _openVisitor() async {
    final visitor = await openRegisterVisitor(context, onChanged: _changed);
    if (visitor == null || !mounted) return;
    final name = visitor.name;
    final message = switch (visitor.status) {
      VisitorStatusValue.approved =>
        '$name is approved — record entry when they walk in.',
      VisitorStatusValue.checkedIn => '$name is inside.',
      VisitorStatusValue.pendingApproval =>
        '$name sent — waiting on the resident to approve.',
      _ => '$name registered.',
    };
    showMessage(context, message);
  }

  Future<void> _openDelivery() async {
    final delivery = await openRegisterDelivery(context, onChanged: _changed);
    if (delivery == null || !mounted) return;
    final message = switch (delivery.status) {
      DeliveryStatusValue.approved =>
        delivery.canLeaveAtGate
            ? 'Approved for collection at the gate.'
            : 'Delivery approved — record entry when it arrives.',
      DeliveryStatusValue.entered => 'Delivery is inside.',
      DeliveryStatusValue.leftAtGate => 'Kept at the gate for collection.',
      DeliveryStatusValue.pendingApproval =>
        'Registered. The resident has been asked to allow it.',
      _ => 'Delivery registered.',
    };
    showMessage(context, message);
  }

  Future<void> _openVerify() async {
    final visitor = await openVerifyPass(context);
    if (visitor == null || !mounted) return;
    HapticFeedback.mediumImpact();
    _changed();
    await showVisitorGateAction(
      context,
      visitor,
      onChanged: _changed,
      passVerified: true,
    );
  }

  Future<void> _openEmergency() async {
    final raised = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RaiseAlertScreen()));
    if (raised == true && mounted) {
      showMessage(
        context,
        'Alert raised. The admin and other guards are notified.',
      );
      _reload();
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _pull,
        color: GateStyle.green,
        backgroundColor: GateStyle.background,
        child: FutureBuilder<GuardDashboard>(
          future: _dashboard,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                !snapshot.hasError) {
              return const GateStatusMessage(
                icon: Icons.hourglass_top_rounded,
                title: 'Loading the gate',
                message: 'Fetching today’s briefing.',
              );
            }
            if (snapshot.hasError) {
              return GateStatusMessage(
                icon: Icons.error_rounded,
                title: 'Could not load the gate',
                message: '${snapshot.error}',
                action: GateButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: _reload,
                ),
              );
            }
            final dashboard = snapshot.data ?? GuardDashboard.empty;
            final session = AppServices.instance.session;
            final mobile = session.identity?.user.mobile;
            return GateHomeScreen(
              embedded: true,
              selectedTab: widget.selectedTab,
              onTabSelected: widget.onTabSelected,
              language: gateIsHindi,
              guardName: session.displayName,
              guardPhone: mobile == null || mobile.trim().isEmpty
                  ? 'On duty'
                  : Fmt.phone(mobile),
              awaiting: dashboard.pendingVisitors + dashboard.pendingDeliveries,
              inside: dashboard.activeVisitors,
              expected: dashboard.expectedVisitors,
              onRegisterVisitor: _openVisitor,
              onVerifyPass: _openVerify,
              onDelivery: _openDelivery,
              onEmergency: _openEmergency,
              onSettings: _openSettings,
            );
          },
        ),
      ),
    );
  }
}
