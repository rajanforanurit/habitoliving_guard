import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/widgets/authed_image.dart';
import 'maid_attendance_screen.dart';
import 'register_delivery_screen.dart';
import 'register_visitor_screen.dart';
import 'tower_flat_selector.dart';
import 'verify_pass_screen.dart';

/// The gate's home screen: who is on duty, the four actions a guard reaches
/// for, and what just happened.
///
/// There is no bottom navigation. The guard works one screen at a time on a
/// phone mounted at the gate, and a tab bar only steals height from the two
/// things that matter: the actions and the activity feed. Everything the bar
/// used to hold now hangs off the profile button in the header.
class GateHomeScreen extends StatelessWidget {
  const GateHomeScreen({
    super.key,
    this.guardName = 'Ramesh',
    this.societyName = '',
    this.guardAvatarFileId,
    this.activities = const [],
    this.language,
    this.onRegisterVisitor,
    this.onVerifyPass,
    this.onDelivery,
    this.onMaidAttendance,
    this.onNotifications,
    this.onProfile,
    this.embedded = false,
  });

  final String guardName;

  /// The society this guard is on duty for.
  final String societyName;

  /// The guard's own profile photo, when one has been uploaded.
  final String? guardAvatarFileId;

  /// The latest gate movement, newest first.
  final List<GateActivity> activities;

  final ValueNotifier<bool>? language;
  final VoidCallback? onRegisterVisitor;
  final VoidCallback? onVerifyPass;
  final VoidCallback? onDelivery;

  /// Opens the attendance form from the gate action grid.
  final VoidCallback? onMaidAttendance;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  /// When true the screen renders only the gate content. The shell supplies the
  /// surrounding scaffold.
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
          children: [
            _Header(
              name: guardName,
              society: societyName,
              avatarFileId: guardAvatarFileId,
              language: notifier,
              onNotifications: onNotifications,
              onProfile: onProfile,
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.24,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                _Action(
                  label: t('Register\nVisitor', 'आगंतुक\nदर्ज करें'),
                  symbol: const Icon(Icons.directions_walk_rounded, size: 52),
                  onTap:
                      onRegisterVisitor ??
                      () => open(RegisterVisitorScreen(language: notifier)),
                ),
                _Action(
                  label: t('Verify Pass', 'पास जाँचें'),
                  symbol: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 40),
                      SizedBox(
                        height: 40,
                        child: VerticalDivider(
                          color: GateStyle.green,
                          width: 10,
                        ),
                      ),
                      Icon(Icons.dialpad_rounded, size: 27),
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
                      Icon(Icons.notes_rounded, size: 19),
                      Icon(Icons.inventory_2_rounded, size: 42),
                    ],
                  ),
                  onTap:
                      onDelivery ??
                      () => open(RegisterDeliveryScreen(language: notifier)),
                ),
                _Action(
                  label: t('Maid\nAttendance', 'मेड\nउपस्थिति'),
                  symbol: const Icon(Icons.cleaning_services_rounded, size: 44),
                  onTap:
                      onMaidAttendance ??
                      () => open(const MaidAttendanceScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RecentActivity(activities: activities, language: hindi),
          ],
        );
        if (embedded) {
          return SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: body,
              ),
            ),
          );
        }
        return GatePage(body: body, maxWidth: 460);
      },
    );
  }
}

/// Who is on duty, and the three controls that sit beside the name.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.society,
    required this.avatarFileId,
    required this.language,
    this.onNotifications,
    this.onProfile,
  });

  final String name;
  final String society;
  final String? avatarFileId;
  final ValueNotifier<bool> language;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final hindi = language.value;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == 'Ramesh' ? gateText(hindi, name, 'रमेश') : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18.4,
                  height: 1.15,
                  color: GateStyle.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (society.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    society.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.4,
                      height: 1.2,
                      color: GateStyle.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GateLanguageButton(notifier: language),
        const SizedBox(width: 6),
        _RoundButton(
          icon: Icons.notifications_none_rounded,
          tooltip: gateText(hindi, 'Notifications', 'सूचनाएँ'),
          onTap: onNotifications,
        ),
        const SizedBox(width: 6),
        _GuardAvatar(name: name, fileId: avatarFileId, onTap: onProfile),
      ],
    );
  }
}

/// The guard's photo, or their initials until one is uploaded.
class _GuardAvatar extends StatelessWidget {
  const _GuardAvatar({required this.name, required this.fileId, this.onTap});

  final String name;
  final String? fileId;
  final VoidCallback? onTap;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final id = fileId?.trim() ?? '';
    final fallback = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      color: GateStyle.mint,
      child: Text(
        Fmt.initials(name).isEmpty ? '?' : Fmt.initials(name),
        style: const TextStyle(
          fontSize: 15.4,
          color: GateStyle.green,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Your profile',
      child: Material(
        color: GateStyle.mint,
        shape: const CircleBorder(side: BorderSide(color: GateStyle.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: id.isEmpty
              ? fallback
              : AuthedImage(
                  fileId: id,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  fallback: fallback,
                ),
        ),
      ),
    );
  }
}

/// A circular header control sized to sit next to the language pill.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Material(
      color: GateStyle.sand,
      shape: const CircleBorder(side: BorderSide(color: GateStyle.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20.5, color: GateStyle.green),
        ),
      ),
    ),
  );
}

/// The last 25 things that happened at this gate, newest first.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.activities, required this.language});

  final List<GateActivity> activities;
  final bool language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: GateStyle.sand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 19,
                color: GateStyle.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gateText(language, 'Recent Activity', 'हाल की गतिविधि'),
                  style: const TextStyle(
                    color: GateStyle.green,
                    fontSize: 15.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (activities.isNotEmpty)
                Text(
                  '${activities.length}',
                  style: const TextStyle(
                    color: GateStyle.muted,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
              child: Text(
                gateText(
                  language,
                  'Nothing at the gate yet.',
                  'अभी गेट पर कुछ नहीं हुआ।',
                ),
                style: const TextStyle(
                  color: GateStyle.muted,
                  fontSize: 13.4,
                  height: 1.35,
                ),
              ),
            )
          else
            for (var i = 0; i < activities.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: GateStyle.line),
              _ActivityRow(activity: activities[i], language: language),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.language});

  final GateActivity activity;
  final bool language;

  @override
  Widget build(BuildContext context) {
    final tone = activity.isPositive ? GateStyle.green : GateStyle.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(_icon(), size: 17, color: tone),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              activity.sentence(hindi: language),
              style: const TextStyle(
                color: GateStyle.ink,
                fontSize: 13.2,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // A backend that has not been updated yet sends no timestamp; show
          // the line without a dangling dash rather than inventing one.
          if (activity.at != null) ...[
            const SizedBox(width: 8),
            Text(
              Fmt.relative(activity.at),
              style: const TextStyle(color: GateStyle.muted, fontSize: 11.2),
            ),
          ],
        ],
      ),
    );
  }

  IconData _icon() {
    if (activity.isMaidAttendance) return Icons.fact_check_outlined;
    if (activity.isDelivery) {
      return activity.isPositive
          ? Icons.inventory_2_rounded
          : Icons.remove_shopping_cart_rounded;
    }
    return switch (activity.status.toUpperCase()) {
      'CHECKED_OUT' => Icons.logout_rounded,
      'CHECKED_IN' => Icons.login_rounded,
      'REJECTED' || 'DENIED' => Icons.block_rounded,
      'PENDING_APPROVAL' => Icons.hourglass_top_rounded,
      _ => Icons.how_to_reg_rounded,
    };
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.symbol, this.onTap});

  final String label;
  final Widget symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GateTile(
    radius: 14,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
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
                    fontSize: 15.2,
                    height: 1.1,
                    color: GateStyle.ink,
                    fontWeight: FontWeight.w800,
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
