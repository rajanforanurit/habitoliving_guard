import 'package:flutter/material.dart';

import 'register_delivery_screen.dart';
import 'register_visitor_screen.dart';
import 'tower_flat_selector.dart';
import 'verify_pass_screen.dart';

enum GateTab { gate, waiting, history, more }

class GateHomeScreen extends StatelessWidget {
  const GateHomeScreen({
    super.key,
    this.guardName = 'Ramesh',
    this.guardPhone = '+91 9000000002',
    this.awaiting = 2,
    this.inside = 5,
    this.expected = 3,
    this.selectedTab = GateTab.gate,
    this.language,
    this.onRegisterVisitor,
    this.onVerifyPass,
    this.onDelivery,
    this.onEmergency,
    this.onSettings,
    this.onTabSelected,
    this.embedded = false,
  });

  final String guardName;
  final String guardPhone;
  final int awaiting;
  final int inside;
  final int expected;
  final GateTab selectedTab;
  final ValueNotifier<bool>? language;
  final VoidCallback? onRegisterVisitor;
  final VoidCallback? onVerifyPass;
  final VoidCallback? onDelivery;
  final VoidCallback? onEmergency;
  final VoidCallback? onSettings;
  final ValueChanged<GateTab>? onTabSelected;

  /// When true the screen renders only the gate content. The shell supplies the
  /// bottom tab bar and the surrounding scaffold.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final notifier = language ?? gateIsHindi;
    void open(Widget screen) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hindi, _) {
        String t(String en, String hi) => gateText(hindi, en, hi);
        final body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 22),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guardName == 'Ramesh'
                            ? t(guardName, 'रमेश')
                            : guardName,
                        style: const TextStyle(
                          fontSize: 24.8,
                          color: GateStyle.green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        guardPhone,
                        style: const TextStyle(
                          fontSize: 14.7,
                          color: GateStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                GateLanguageButton(notifier: notifier),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: t('Settings', 'सेटिंग्स'),
                  color: GateStyle.green,
                  disabledColor: GateStyle.green,
                  iconSize: 30,
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            const SizedBox(height: 30),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.97,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                _Action(
                  label: t('Register\nVisitor', 'आगंतुक\nदर्ज करें'),
                  symbol: const Icon(Icons.directions_walk_rounded, size: 76.4),
                  onTap:
                      onRegisterVisitor ??
                      () => open(RegisterVisitorScreen(language: notifier)),
                ),
                _Action(
                  label: t('Verify Pass', 'पास जाँचें'),
                  symbol: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 58.9),
                      SizedBox(
                        height: 60,
                        child: VerticalDivider(
                          color: GateStyle.green,
                          width: 14,
                        ),
                      ),
                      Icon(Icons.dialpad_rounded, size: 40.5),
                    ],
                  ),
                  onTap:
                      onVerifyPass ??
                      () => open(VerifyPassScreen(language: notifier)),
                ),
                _Action(
                  label: t('Delivery', 'डिलीवरी'),
                  symbol: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_rounded, size: 27.6),
                      Icon(Icons.inventory_2_rounded, size: 60.7),
                    ],
                  ),
                  onTap:
                      onDelivery ??
                      () => open(RegisterDeliveryScreen(language: notifier)),
                ),
                _Action(
                  label: t('Emergency\nAlert', 'आपातकालीन\nअलर्ट'),
                  symbol: const Icon(
                    Icons.warning_rounded,
                    color: GateStyle.red,
                    size: 78.2,
                  ),
                  onTap: onEmergency,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 13, 12, 15),
              decoration: BoxDecoration(
                color: GateStyle.pink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_rounded, color: GateStyle.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t('Needs a decision', 'फ़ैसला बाकी है'),
                          style: const TextStyle(
                            color: Color(0xFF861F1F),
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _Metric(awaiting, t('Awaiting', 'इंतज़ार में')),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0xFFE1B5B5),
                        ),
                        _Metric(inside, t('Inside', 'अंदर')),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0xFFE1B5B5),
                        ),
                        _Metric(expected, t('Expected', 'आने वाले')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (embedded) {
          return SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: body,
              ),
            ),
          );
        }
        return GatePage(
          body: body,
          footer: GateTabBar(
            selectedTab: selectedTab,
            onTabSelected: onTabSelected,
            language: notifier,
          ),
        );
      },
    );
  }
}

/// The four-tab bottom bar shared by the gate screen and the shell.
class GateTabBar extends StatelessWidget {
  const GateTabBar({
    super.key,
    required this.selectedTab,
    this.onTabSelected,
    this.language,
  });

  final GateTab selectedTab;
  final ValueChanged<GateTab>? onTabSelected;
  final ValueNotifier<bool>? language;

  @override
  Widget build(BuildContext context) {
    final notifier = language ?? gateIsHindi;
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hindi, _) {
        String t(String en, String hi) => gateText(hindi, en, hi);
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: GateStyle.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tab(GateTab.gate, t('Gate', 'गेट'), Icons.fence_rounded),
                _tab(
                  GateTab.waiting,
                  t('Waiting', 'इंतज़ार'),
                  Icons.groups_outlined,
                ),
                _tab(GateTab.history, t('History', 'इतिहास'), Icons.schedule),
                _tab(GateTab.more, t('More', 'और'), Icons.more_horiz),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tab(GateTab tab, String label, IconData icon) {
    final selected = selectedTab == tab;
    final color = selected ? Colors.white : GateStyle.muted;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GateTile(
          selected: selected,
          color: selected ? GateStyle.green : GateStyle.background,
          onTap: onTabSelected == null ? null : () => onTabSelected!(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 29.4),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.symbol, this.onTap});

  final String label;
  final Widget symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GateTile(
    radius: 17,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconTheme(
                data: const IconThemeData(color: GateStyle.green),
                child: symbol,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19.3,
                    height: 1.12,
                    color: GateStyle.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.count, this.label);

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: const TextStyle(
                color: GateStyle.green,
                fontSize: 33.1,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GateStyle.muted),
          ),
        ],
      ),
    ),
  );
}
