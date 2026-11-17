import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// The shift log: everything that happened today at this gate, in one place.
///
/// This is the handover screen. A guard coming on shift needs three facts:
/// who is inside, who is expected, and what went wrong. Each is a separate
/// fetch so one slow call does not blank the other two.
class LogTab extends StatefulWidget {
  const LogTab({super.key});

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  late Future<List<Visitor>> _inside;
  late Future<List<Visitor>> _history;
  late Future<List<Visitor>> _expected;
  late Future<GuardDashboard> _dashboard;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final guard = AppServices.instance.guard;
    _inside = guard.activeVisitors();
    _history = guard.visitors(limit: 30).then((p) => p.items);
    _expected = guard.expectedVisitors();
    _dashboard = guard.dashboard();
  }

  Future<void> _pull() async {
    _reload();
    setState(() {});
    try {
      await Future.wait([_inside, _history, _expected, _dashboard]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Shift log',
      subtitle: 'What happened today',
      onRefresh: _pull,
      body: RefreshIndicator(
        onRefresh: _pull,
        color: Tokens.accent,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space6),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space3,
              ),
              child: Text(
                'Shift handed over',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            _SummaryPanel(
              inside: _inside,
              expected: _expected,
              today: _dashboard.then(
                (d) => d.todayVisitors + d.todayDeliveries,
              ),
            ),

            const SizedBox(height: Tokens.space6),
            const _SectionHeader(icon: Icons2.gate, title: 'Inside right now'),
            _VisitorsPanel(
              future: _inside,
              emptyTitle: 'Nobody inside',
              emptyMessage:
                  'Visitors cleared to enter stay listed here until they leave.',
            ),

            const SizedBox(height: Tokens.space6),
            const _SectionHeader(
              icon: Icons2.visitors,
              title: 'Expected today',
            ),
            _VisitorsPanel(
              future: _expected,
              emptyTitle: 'Nobody expected',
              emptyMessage:
                  'Residents who issued a pass for today appear here.',
            ),

            const SizedBox(height: Tokens.space6),
            const _SectionHeader(
              icon: Icons2.reports,
              title: 'Recent movement',
            ),
            _VisitorsPanel(
              future: _history,
              emptyTitle: 'No movement logged yet',
              emptyMessage:
                  'Every entry, exit, denial and registration lands here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.space4,
        0,
        Tokens.space4,
        Tokens.space3,
      ),
      child: Row(
        children: [
          AppIcon(icon, size: IconSize.inline, color: Tokens.inkMuted),
          SizedBox(width: Tokens.space2),
          Text(
            title,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              fontWeight: FontWeight.w600,
              color: Tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The counts a handover actually needs.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.inside,
    required this.expected,
    required this.today,
  });

  final Future<List<Visitor>> inside;
  final Future<List<Visitor>> expected;
  final Future<int> today;

  @override
  Widget build(BuildContext context) {
    return Panel(
      margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: Row(
        children: [
          _Count(future: inside, label: 'Inside', icon: Icons2.gate),
          _Divider(),
          _Count(future: expected, label: 'Expected', icon: Icons2.visitors),
          _Divider(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.space4),
              child: Column(
                children: [
                  FutureBuilder<int>(
                    future: today,
                    builder: (context, snapshot) {
                      final n = snapshot.data;
                      return Text(
                        n == null ? '—' : '$n',
                        style: TextStyle(
                          fontFamily: Tokens.fontFamilyFigure,
                          fontSize: Tokens.typeXl,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: Tokens.ink,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(Icons2.reports, size: 14, color: Tokens.inkFaint),
                      SizedBox(width: 4),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeXs,
                          color: Tokens.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    return Container(width: 1, height: 40, color: Tokens.line);
  }
}

class _Count<T> extends StatelessWidget {
  const _Count({required this.future, required this.label, required this.icon});
  final Future<List<T>> future;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Tokens.space4),
        child: Column(
          children: [
            FutureBuilder<List<T>>(
              future: future,
              builder: (context, snapshot) {
                final n = snapshot.data?.length;
                return Text(
                  n == null ? '—' : '$n',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamilyFigure,
                    fontSize: Tokens.typeXl,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                );
              },
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 14, color: Tokens.inkFaint),
                SizedBox(width: 4),
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
          ],
        ),
      ),
    );
  }
}

/// A visitor list with a real empty state per section.
class _VisitorsPanel extends StatelessWidget {
  const _VisitorsPanel({
    required this.future,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final Future<List<Visitor>> future;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Panel(
      margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: FutureBuilder<List<Visitor>>(
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
              padding: const EdgeInsets.all(Tokens.space4),
              child: ErrorState(compact: true, message: '${snapshot.error}'),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return EmptyState(
              compact: true,
              icon: Icons2.empty,
              title: emptyTitle,
              message: emptyMessage,
            );
          }
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Hairline(indent: Tokens.space4),
                ListRow(
                  dense: true,
                  title: items[i].name,
                  subtitle: [
                    if (items[i].flatLabel != null) items[i].flatLabel!,
                    if (items[i].checkedInAt != null)
                      'in ${Fmt.time(items[i].checkedInAt)}',
                    if (items[i].checkedOutAt != null)
                      'out ${Fmt.time(items[i].checkedOutAt)}',
                  ].join(' · '),
                  leading: const AppIcon(Icons2.visitors, size: IconSize.row),
                  trailing: StatusBadge.forStatus(
                    items[i].status.name,
                    domain: StatusDomain.visitor,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
