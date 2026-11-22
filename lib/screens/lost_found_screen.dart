import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../app.dart';
import 'widgets/paged_list.dart';

/// The guard's lost-and-found register.
class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  String? _kind;
  int _revision = 0;

  Future<void> _report() async {
    final type = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _LostFoundReport(initialType: _kind ?? 'FOUND'),
      ),
    );
    if (!mounted || type == null) return;
    setState(() {
      _kind = type;
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Lost & found',
      floatingAction: FloatingActionButton.extended(
        onPressed: _report,
        icon: const AppIcon(Icons2.add),
        label: const Text('Report item'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: Row(
              children: [
                _Filter(
                  label: 'All',
                  selected: _kind == null,
                  onTap: () => setState(() => _kind = null),
                ),
                const SizedBox(width: Tokens.space2),
                _Filter(
                  label: 'Lost',
                  selected: _kind == 'LOST',
                  onTap: () => setState(() => _kind = 'LOST'),
                ),
                const SizedBox(width: Tokens.space2),
                _Filter(
                  label: 'Found',
                  selected: _kind == 'FOUND',
                  onTap: () => setState(() => _kind = 'FOUND'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<LostFoundItem>(
              key: ValueKey((_kind, _revision)),
              padding: const EdgeInsets.only(bottom: 76),
              fetch: (page) => AppServices.instance.guard.lostAndFound(
                page: page,
                type: _kind,
              ),
              emptyTitle: 'Nothing logged',
              emptyMessage:
                  'Items handed in at the gate and things reported '
                  'missing appear here.',
              emptyIcon: Icons2.lostFound,
              itemBuilder: (context, item, _) {
                return ListRow(
                  title: item.title,
                  subtitle: [
                    item.kind,
                    if (item.location != null) item.location!,
                    if (item.createdAt != null) Fmt.relative(item.createdAt),
                  ].join(' · '),
                  icon: Icons2.lostFound,
                  trailing: StatusBadge.forStatus(item.status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Tokens.accentTint : Tokens.surface,
      borderRadius: BorderRadius.circular(Tokens.radiusFull),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(color: selected ? Tokens.accent : Tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              fontWeight: FontWeight.w500,
              color: selected ? Tokens.accent : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LostFoundReport extends StatefulWidget {
  const _LostFoundReport({required this.initialType});

  final String initialType;

  @override
  State<_LostFoundReport> createState() => _LostFoundReportState();
}

class _LostFoundReportState extends State<_LostFoundReport> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  late String _type = widget.initialType;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.guard.reportLostAndFound(
        type: _type,
        title: _title.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Item recorded.');
      Navigator.of(context).pop(_type);
    } catch (error) {
      if (mounted) showMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Report an item',
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Report type'),
            items: const [
              DropdownMenuItem(value: 'FOUND', child: Text('Found')),
              DropdownMenuItem(value: 'LOST', child: Text('Lost')),
            ],
            onChanged: _busy ? null : (value) => setState(() => _type = value!),
          ),
          TextFormField(
            controller: _title,
            enabled: !_busy,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Item name'),
            validator: (value) =>
                (value ?? '').trim().length < 3 ? 'Enter an item name.' : null,
          ),
          TextFormField(
            controller: _location,
            enabled: !_busy,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Location (optional)'),
          ),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save report'),
          ),
        ],
      ),
    ),
  );
}
