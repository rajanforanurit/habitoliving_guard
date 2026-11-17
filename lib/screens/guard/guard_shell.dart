import 'package:flutter/material.dart';

import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/widgets/bottom_nav.dart';
import '../../services/notification_router.dart';
import 'gate_tab.dart';
import 'deliveries_tab.dart';
import 'alerts_tab.dart';
import 'log_tab.dart';
import 'guard_more_tab.dart';
import '../widgets/tab_host.dart';

/// Guard navigation.
///
/// The gate is a standing job, so the tabs follow the shift rather than a
/// feature list:
///   Gate       — today's briefing, visitors at the gate, verify a pass
///   Deliveries — parcels in, parcels out, gate handovers
///   Alerts     — panic alerts and incidents
///   Log        — everything that happened today, for the handover
///   More       — shift summary, emergency numbers, settings
///
/// Tab state lives here so a notification tap can open a specific tab without
/// rebuilding the tree.
class GuardShell extends StatefulWidget {
  const GuardShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends State<GuardShell> with TabHost<GuardShell> {
  late int _index = widget.initialTab;
  late final Registration _routes;

  static const _destinations = [
    NavDestination(icon: Icons2.gate, activeIcon: Icons2.gate, label: 'Gate'),
    NavDestination(
      icon: Icons2.deliveries,
      activeIcon: Icons2.deliveries,
      label: 'Deliveries',
    ),
    NavDestination(
      icon: Icons2.incidents,
      activeIcon: Icons2.incidents,
      label: 'Alerts',
    ),
    NavDestination(
      icon: Icons2.reports,
      activeIcon: Icons2.reports,
      label: 'Log',
    ),
    NavDestination(
      icon: Icons2.profile,
      activeIcon: Icons2.profile,
      label: 'More',
    ),
  ];

  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.initialTab);
    listenForTabRequests();
    _routes = NotificationRouter.register(
      const {},
      tabSections: const {
        'gate': 0,
        'visitor': 0,
        'visitors': 0,
        'expected': 0,
        'deliveries': 1,
        'delivery': 1,
        'alerts': 2,
        'alert': 2,
        'panic': 2,
        'incident': 2,
        'incidents': 2,
        'log': 3,
      },
    );
  }

  @override
  void dispose() {
    _routes.dispose();
    super.dispose();
  }

  @override
  void onTabRequest(int index) => _select(index);

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      destinations: _destinations,
      index: _index,
      onSelected: _select,
      child: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i)
                ? switch (i) {
                    0 => const GateTab(),
                    1 => const DeliveriesTab(),
                    2 => const AlertsTab(),
                    3 => const LogTab(),
                    _ => const GuardMoreTab(),
                  }
                : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
