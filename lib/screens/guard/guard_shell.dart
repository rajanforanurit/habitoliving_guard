import 'package:flutter/material.dart';

import '../../services/notification_router.dart';
import 'alerts_tab.dart';
import '../calls/call_contacts_screen.dart';
import 'deliveries_tab.dart';
import 'gate_home_tab.dart';
import 'guard_profile_screen.dart';
import 'log_tab.dart';
import 'tower_flat_selector.dart';

/// Guard navigation.
///
/// There is no bottom navigation bar. The gate is a standing job on a phone
/// mounted at the door, and a four-tab bar cost height the guard needs for the
/// actions and the activity feed. The gate page is the whole app; everything
/// else — the shift log, deliveries, alerts, the profile — is reached from the
/// profile button in the page header.
class GuardShell extends StatefulWidget {
  const GuardShell({super.key});

  @override
  State<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends State<GuardShell> {
  final ValueNotifier<int> _gateRefresh = ValueNotifier<int>(0);
  Registration? _routes;

  @override
  void initState() {
    super.initState();
    _routes = NotificationRouter.register({
      // Every section used to map to a tab index. With the bar gone the same
      // taps open the screen that owns the thing.
      'gate': (_) => _RefreshGate(onDone: _refreshGate),
      'visitor': (_) => _RefreshGate(onDone: _refreshGate),
      'visitors': (_) => _RefreshGate(onDone: _refreshGate),
      'expected': (_) => _RefreshGate(onDone: _refreshGate),
      'deliveries': (_) => const DeliveriesTab(),
      'delivery': (_) => const DeliveriesTab(),
      'log': (_) => const LogTab(),
      'history': (_) => const LogTab(),
      'more': (_) => const GuardProfileScreen(),
      'profile': (_) => const GuardProfileScreen(),
      'alerts': (_) => const AlertsTab(),
      'alert': (_) => const AlertsTab(),
      'incidents': (_) => const AlertsTab(),
      'incident': (_) => const AlertsTab(),
      'call': (_) => const CallContactsScreen(),
      'calls': (_) => const CallContactsScreen(),
    });
  }

  @override
  void dispose() {
    _gateRefresh.dispose();
    _routes?.dispose();
    super.dispose();
  }

  void _refreshGate() => _gateRefresh.value++;

  @override
  Widget build(BuildContext context) {
    return IncomingCallOverlay(
      child: Scaffold(
        backgroundColor: GateStyle.background,
        body: GateHomeTab(refreshTick: _gateRefresh),
      ),
    );
  }
}

/// A notification about something already on screen.
///
/// Rather than pushing a second copy of the gate, it reloads the open one and
/// closes itself on the next frame.
class _RefreshGate extends StatefulWidget {
  const _RefreshGate({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_RefreshGate> createState() => _RefreshGateState();
}

class _RefreshGateState extends State<_RefreshGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDone();
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: GateStyle.background,
    body: Center(child: CircularProgressIndicator()),
  );
}
