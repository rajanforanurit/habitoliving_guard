import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../emergency_screen.dart';
import '../lost_found_screen.dart';
import '../notifications_inbox_screen.dart';
import '../settings_screen.dart';
import 'alerts_tab.dart';
import '../calls/call_contacts_screen.dart';
import 'deliveries_tab.dart';
import 'domestic_help_screen.dart';
import 'emergency_entry_screen.dart';
import 'guard_helpdesk_screen.dart';
import 'log_tab.dart';

/// Guard's More tab: the things a guard reaches for between rounds.
///
/// Ordered by shift reality: emergency numbers first (a guard calls before they
/// read), then the two reference lists they need at the gate, then the account.
///
/// The rows live in [GuardMoreList] so the profile page can show the same set
/// without a second copy to maintain.
class GuardMoreTab extends StatefulWidget {
  const GuardMoreTab({super.key});

  @override
  State<GuardMoreTab> createState() => _GuardMoreTabState();
}

class _GuardMoreTabState extends State<GuardMoreTab> {
  late final _gate = AppServices.instance.guard.myGate();

  @override
  Widget build(BuildContext context) {
    final session = AppServices.instance.session;
    return AppScaffold(
      title: 'More',
      subtitle: session.societyName,
      body: ListView(
        padding: const EdgeInsets.only(
          left: Tokens.gutter,
          right: Tokens.gutter,
          bottom: kScreenBottomPadding,
        ),
        children: [
          FutureBuilder(
            future: _gate,
            builder: (context, snapshot) => _ProfileCard(
              name: session.displayName,
              mobile: session.identity?.user.mobile,
              gate: snapshot.data ?? 'On duty',
              onSettings: () => _go(context, const SettingsScreen()),
            ),
          ),
          const GuardMoreList(),
          const SizedBox(height: Tokens.space6),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// The gate's secondary screens, as a plain column.
///
/// Callers own the scroll view and its padding, so this can sit under a profile
/// card or on its own.
class GuardMoreList extends StatelessWidget {
  const GuardMoreList({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('At the gate'),
        const SizedBox(height: Tokens.space2),
        Panel(
          child: Column(
            children: [
              ListRow(
                title: 'Emergency numbers',
                subtitle: 'One tap to call',
                icon: Icons2.emergency,
                onTap: () => go(const EmergencyScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'Emergency entry',
                icon: Icons2.gate,
                onTap: () => go(const EmergencyEntryScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'Domestic help',
                icon: Icons2.community,
                onTap: () => go(const DomesticHelpScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'Helpdesk directory',
                icon: Icons2.phone,
                onTap: () => go(const GuardHelpdeskScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'In-app calls',
                icon: Icons2.phone,
                onTap: () => go(const CallContactsScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'Deliveries',
                subtitle: 'The full gate register',
                icon: Icons2.deliveries,
                onTap: () => go(const DeliveriesTab()),
              ),
              const Hairline(),
              ListRow(
                title: 'Active alerts',
                subtitle: 'Panic alerts and incidents',
                icon: Icons2.incidents,
                onTap: () => go(const AlertsTab()),
              ),
              const Hairline(),
              ListRow(
                title: 'Lost & found',
                subtitle: 'Parcels, keys and valuables handed in',
                icon: Icons2.lostFound,
                onTap: () => go(const LostFoundScreen()),
              ),
              const Hairline(),
              ListRow(
                title: 'Notifications',
                subtitle: 'Approvals, alerts and handovers',
                icon: Icons2.notifications,
                onTap: () => go(const NotificationsInboxScreen()),
              ),
            ],
          ),
        ),
        const SectionLabel('Account'),
        const SizedBox(height: Tokens.space2),
        Panel(
          child: Column(
            children: [
              ListRow(
                title: 'Shift log',
                subtitle: 'Everyone inside, expected and turned away',
                icon: Icons2.gate,
                onTap: () => go(const LogTab()),
              ),
              const Hairline(),
              ListRow(
                title: 'Settings',
                subtitle: 'Theme, notifications and security',
                icon: Icons2.settings,
                onTap: () => go(const SettingsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.mobile,
    required this.gate,
    required this.onSettings,
  });

  final String name;
  final String? mobile;
  final String gate;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Tokens.space6),
      child: Container(
        padding: EdgeInsets.all(Tokens.space4),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: 40.5),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeBase,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  Text(
                    [
                      gate,
                      if (mobile != null && mobile!.isNotEmpty) mobile!,
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSettings,
              icon: const AppIcon(Icons2.settings),
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
