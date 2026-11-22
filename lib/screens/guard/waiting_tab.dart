import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/authed_image.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Everything that is waiting on the guard right now.
///
/// The gate screen shows the counts; this tab is the queue behind them. Two
/// lists only: visitors waiting for the resident's decision, and deliveries
/// waiting for the resident to allow or refuse them. Each row carries the
/// action that is legal for it, so the guard never has to open a detail screen
/// to do the obvious thing.
class WaitingTab extends StatefulWidget {
  const WaitingTab({super.key, this.active = true});

  final bool active;

  @override
  State<WaitingTab> createState() => _WaitingTabState();
}

class _WaitingTabState extends State<WaitingTab> {
  late Future<List<Visitor>> _visitors;
  late Future<List<Delivery>> _deliveries;
  final List<void Function()> _unsubscribers = [];

  @override
  void initState() {
    super.initState();
    _reload();
    final socket = AppServices.instance.socket;
    for (final event in const [
      Events.visitorArrived,
      Events.visitorDecision,
      Events.visitorEntered,
      Events.visitorExited,
      Events.visitorDenied,
      Events.visitorOverstay,
      Events.deliveryArrived,
      Events.deliveryDecision,
    ]) {
      _unsubscribers.add(
        socket.on(event, (_) {
          if (mounted) _reload();
        }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant WaitingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _reload();
  }

  @override
  void dispose() {
    for (final unsubscribe in _unsubscribers) {
      unsubscribe();
    }
    super.dispose();
  }

  void _reload() {
    final guard = AppServices.instance.guard;
    _visitors = guard.pendingVisitors();
    _deliveries = guard
        .deliveries(limit: 20, status: 'PENDING_APPROVAL')
        .then((page) => page.items);
    if (mounted) setState(() {});
  }

  Future<void> _pull() async {
    _reload();
    try {
      await Future.wait([_visitors, _deliveries]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _visitorActions(Visitor visitor) async {
    final guard = AppServices.instance.guard;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                visitor.name,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeLg,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                [
                  if (visitor.flatLabel != null) visitor.flatLabel!,
                  if (visitor.purpose != null) visitor.purpose!,
                  if (visitor.phone != null) Fmt.phone(visitor.phone),
                ].join(' · '),
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.inkMuted,
                ),
              ),
              SizedBox(height: Tokens.space5),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('notify'),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Re-notify the resident'),
              ),
              const SizedBox(height: Tokens.space2),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop('deny'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.danger,
                  side: BorderSide(color: Tokens.danger),
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Deny entry'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'notify') {
        await guard.requestApproval(visitor.id);
        if (mounted) showMessage(context, 'The resident has been asked again.');
      } else {
        await guard.denyEntry(visitor.id, reason: 'Declined at the gate');
        if (mounted) showMessage(context, 'Entry denied.');
      }
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _deliveryActions(Delivery delivery) async {
    final guard = AppServices.instance.guard;
    final action = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                delivery.courier ?? 'Delivery',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeLg,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                [
                  if (delivery.flatLabel != null) delivery.flatLabel!,
                  if (delivery.type != null) delivery.type!,
                ].join(' · '),
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.inkMuted,
                ),
              ),
              SizedBox(height: Tokens.space5),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Re-notify the resident'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action != true || !mounted) return;
    try {
      await guard.requestDeliveryApproval(delivery.id);
      if (!mounted) return;
      showMessage(context, 'The resident has been asked again.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Waiting',
      subtitle: 'Awaiting a decision',
      onRefresh: _pull,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Tokens.space6),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space4,
              Tokens.space2,
            ),
            child: SectionLabel('Visitors'),
          ),
          _ListPanel<Visitor>(
            future: _visitors,
            icon: Icons2.visitors,
            emptyTitle: 'Nobody is waiting',
            emptyMessage:
                'Walk-in registrations land here until the resident decides.',
            itemBuilder: (visitor) => ListRow(
              title: visitor.name,
              subtitle: [
                if (visitor.flatLabel != null) visitor.flatLabel!,
                if (visitor.purpose != null) visitor.purpose!,
                if (visitor.phone != null) Fmt.phone(visitor.phone),
              ].join(' · '),
              leading: visitor.photoFileId != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      child: AuthedImage(
                        fileId: visitor.photoFileId!,
                        width: 40,
                        height: 40,
                      ),
                    )
                  : const AppIcon(Icons2.visitors, size: IconSize.row),
              trailing: const MetaTag('Waiting'),
              onTap: () => _visitorActions(visitor),
            ),
          ),
          const SizedBox(height: Tokens.space5),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space4,
              Tokens.space2,
            ),
            child: SectionLabel('Deliveries'),
          ),
          _ListPanel<Delivery>(
            future: _deliveries,
            icon: Icons2.deliveries,
            emptyTitle: 'No parcels waiting',
            emptyMessage:
                'Courier registrations appear here for the resident to allow or refuse.',
            itemBuilder: (delivery) => ListRow(
              title: delivery.courier ?? 'Delivery',
              subtitle: [
                if (delivery.flatLabel != null) delivery.flatLabel!,
                if (delivery.type != null) delivery.type!,
                if (delivery.arrivedAt != null)
                  Fmt.relative(delivery.arrivedAt),
              ].join(' · '),
              leading: const AppIcon(Icons2.deliveries, size: IconSize.row),
              trailing: const MetaTag('Waiting'),
              onTap: () => _deliveryActions(delivery),
            ),
          ),
        ],
      ),
    );
  }
}

/// A panel that loads independently and has a real empty state.
class _ListPanel<T> extends StatelessWidget {
  const _ListPanel({
    required this.future,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final Future<List<T>> future;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Panel(
      margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              !snapshot.hasError) {
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
              padding: EdgeInsets.all(Tokens.space4),
              child: Text(
                '${snapshot.error}',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.danger,
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return EmptyState(
              compact: true,
              icon: icon,
              title: emptyTitle,
              message: emptyMessage,
            );
          }
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Hairline(indent: Tokens.space4),
                itemBuilder(items[i]),
              ],
              const SizedBox(height: Tokens.space2),
            ],
          );
        },
      ),
    );
  }
}
