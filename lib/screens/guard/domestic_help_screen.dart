import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

import '../../app.dart';

class DomesticHelpScreen extends StatefulWidget {
  const DomesticHelpScreen({super.key});

  @override
  State<DomesticHelpScreen> createState() => _DomesticHelpScreenState();
}

class _DomesticHelpScreenState extends State<DomesticHelpScreen> {
  final _guard = AppServices.instance.guard;
  final _code = TextEditingController();
  late Future<List<ExpectedHelper>> _roster = _guard.expectedHelpers();
  Map<String, dynamic>? _helper;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verifyOrRecord() async {
    if (_busy || _code.text.length != 6) return;
    final code = _code.text;
    final helper = _helper;
    setState(() => _busy = true);
    try {
      final result = await (helper == null
          ? _guard.lookupHelper(code)
          : asBool(helper['checkedIn'])
          ? _guard.checkOutHelper(code)
          : _guard.checkInHelper(code));
      if (mounted) setState(() => _helper = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _helper = null);
      showMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = _helper;
    final checkedIn = asBool(helper?['checkedIn']);
    return AppScaffold(
      title: 'Domestic help',
      onRefresh: () async {
        setState(() => _roster = _guard.expectedHelpers());
        try {
          await _roster;
        } catch (_) {
          // The roster displays the request error.
        }
      },
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Six-digit entry code',
            ),
            onChanged: (_) => setState(() => _helper = null),
          ),
          if (helper != null)
            ListRow(
              title: asString(helper['name'], fallback: 'Worker'),
              subtitle: [
                checkedIn ? 'Checked in' : 'Verified',
                ...asMapList(helper['assignedFlats'])
                    .map((f) => asString(f['flatLabel']))
                    .where((label) => label.isNotEmpty),
              ].join(' · '),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || _code.text.length != 6 ? null : _verifyOrRecord,
            child: Text(
              _busy
                  ? 'Please wait…'
                  : helper == null
                  ? 'Verify worker'
                  : checkedIn
                  ? 'Check out'
                  : 'Check in',
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const _UnauthorizedHelperScreen(),
                    ),
                  ),
            child: const Text('Report an unauthorized visit'),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Verified workers'),
          FutureBuilder(
            future: _roster,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(compact: true, message: '${snapshot.error}');
              }
              final helpers = snapshot.data;
              if (helpers == null) return const LinearProgressIndicator();
              if (helpers.isEmpty) {
                return const EmptyState(
                  title: 'No workers on the roster',
                  compact: true,
                );
              }
              return Column(
                children: [
                  for (final worker in helpers)
                    ListRow(
                      title: worker.name,
                      subtitle: [worker.type, ?worker.flatLabel].join(' · '),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UnauthorizedHelperScreen extends StatefulWidget {
  const _UnauthorizedHelperScreen();

  @override
  State<_UnauthorizedHelperScreen> createState() =>
      _UnauthorizedHelperScreenState();
}

class _UnauthorizedHelperScreenState extends State<_UnauthorizedHelperScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _report() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.guard.reportUnauthorizedHelper(
        description: _description.text.trim(),
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Incident reported.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Unauthorized visit',
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextFormField(
            controller: _name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Name (optional)'),
          ),
          TextFormField(
            controller: _description,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'What happened?'),
            validator: (value) => (value ?? '').trim().length < 5
                ? 'Enter at least five characters.'
                : null,
          ),
          FilledButton(
            onPressed: _busy ? null : _report,
            child: const Text('Report visit'),
          ),
        ],
      ),
    ),
  );
}
