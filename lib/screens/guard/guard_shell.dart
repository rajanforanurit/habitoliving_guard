import 'package:flutter/material.dart';

import '../../services/notification_router.dart';
import 'alerts_tab.dart';
import '../calls/call_contacts_screen.dart';
import 'gate_home_screen.dart';
import 'gate_home_tab.dart';
import 'guard_more_tab.dart';
import 'log_tab.dart';
import 'tower_flat_selector.dart';
import 'waiting_tab.dart';
import '../widgets/tab_host.dart';

/// Guard navigation.
///
/// The gate is a standing job, so the tabs follow the shift rather than a
/// feature list:
///   Gate     — today's briefing, the four gate actions and live counts
///   Waiting  — visitors and deliveries awaiting a decision
///   History  — everything that happened today, for the handover
///   More     — deliveries, alerts, emergency numbers, settings
///
/// The bottom bar is the gate design's own four-tab bar, shared with the
/// standalone `GateHomeScreen`.
class GuardShell extends StatefulWidget {
  const GuardShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends State<GuardShell> with TabHost<GuardShell> {
  late int _index = widget.initialTab;
  late final Registration _routes;
  final ValueNotifier<int> _gateRefresh = ValueNotifier<int>(0);

  final _visited = <int>{0};

  static const _tabCount = 4;

  @override
  int get tabCount => _tabCount;

  @override
  void initState() {
    super.initState();
    _visited.add(widget.initialTab);
    listenForTabRequests();
    _routes = NotificationRouter.register(
      {
        // Alerts and incidents do not own a bottom tab any more; open the live
        // list instead of switching to a tab that no longer exists.
        'call': (_) => const CallContactsScreen(),
        'calls': (_) => const CallContactsScreen(),
        'alerts': (data) => const AlertsTab(),
        'alert': (data) => const AlertsTab(),
        'incidents': (data) => const AlertsTab(),
        'incident': (data) => const AlertsTab(),
      },
      tabSections: const {
        'gate': 0,
        'visitor': 0,
        'visitors': 0,
        'expected': 0,
        'deliveries': 1,
        'delivery': 1,
        'log': 2,
        'history': 2,
        'more': 3,
      },
    );
  }

  @override
  void dispose() {
    _gateRefresh.dispose();
    _routes.dispose();
    super.dispose();
  }

  @override
  void onTabRequest(int index) => _select(index);

  void _select(int index) {
    if (index < 0 || index >= _tabCount) return;
    if (index == _index) {
      if (index == 0) _gateRefresh.value++;
      return;
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
    if (index == 0) _gateRefresh.value++;
  }

  GateTab get _gateTab => switch (_index) {
    1 => GateTab.waiting,
    2 => GateTab.history,
    3 => GateTab.more,
    _ => GateTab.gate,
  };

  void _onGateTab(GateTab tab) {
    _select(switch (tab) {
      GateTab.waiting => 1,
      GateTab.history => 2,
      GateTab.more => 3,
      GateTab.gate => 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return IncomingCallOverlay(
      child: Scaffold(
        backgroundColor: GateStyle.background,
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabCount; i++)
              _visited.contains(i)
                  ? switch (i) {
                      0 => GateHomeTab(
                        selectedTab: _gateTab,
                        onTabSelected: _onGateTab,
                        refreshTick: _gateRefresh,
                      ),
                      1 => WaitingTab(active: _index == i),
                      2 => LogTab(active: _index == i),
                      _ => const GuardMoreTab(),
                    }
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: GateTabBar(
            selectedTab: _gateTab,
            onTabSelected: _onGateTab,
            language: gateIsHindi,
          ),
        ),
      ),
    );
  }
}
