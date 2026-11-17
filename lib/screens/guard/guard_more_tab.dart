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

/// Guard's More tab: the things a guard reaches for between rounds.
///
/// Ordered by shift reality: emergency numbers first (a guard calls before they
/// read), then the two reference lists they need at the gate, then the account.
class GuardMoreTab extends StatelessWidget {
  const GuardMoreTab({super.key});

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
          _ProfileCard(
            name: session.displayName,
            mobile: session.identity?.user.mobile,
            gate: 'On duty',
            onSettings: () => _go(context, const SettingsScreen()),
          ),

          const SectionLabel('At the gate'),
          const SizedBox(height: Tokens.space2),
          Panel(
            child: Column(
              children: [
                ListRow(
                  title: 'Emergency numbers',
                  subtitle: 'One tap to call',
                  icon: Icons2.emergency,
                  onTap: () => _go(context, const EmergencyScreen()),
                ),
                const Hairline(),
                ListRow(
                  title: 'Lost & found',
                  subtitle: 'Parcels, keys and valuables handed in',
                  icon: Icons2.lostFound,
                  onTap: () => _go(context, const LostFoundScreen()),
                ),
                const Hairline(),
                ListRow(
                  title: 'Notifications',
                  subtitle: 'Approvals, alerts and handovers',
                  icon: Icons2.notifications,
                  onTap: () => _go(context, const NotificationsInboxScreen()),
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
                  title: 'Settings',
                  subtitle: 'Theme, notifications and security',
                  icon: Icons2.settings,
                  onTap: () => _go(context, const SettingsScreen()),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
            InitialsAvatar(name: name, size: 44),
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
