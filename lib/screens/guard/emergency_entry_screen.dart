import 'package:flutter/material.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

import '../../app.dart';
import 'gate_flows.dart';
import 'tower_flat_selector.dart';

class EmergencyEntryScreen extends StatefulWidget {
  const EmergencyEntryScreen({super.key});

  @override
  State<EmergencyEntryScreen> createState() => _EmergencyEntryScreenState();
}

class _EmergencyEntryScreenState extends State<EmergencyEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reason = TextEditingController();
  late Future<SocietyPropertyInfo> _directory = GateDirectory.load();
  String? _flat;
  String _purpose = 'Ambulance';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _record(SocietyPropertyInfo directory) async {
    final flat = _flat;
    if (_busy || flat == null || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final flatId = await resolveGateFlatId(directory, flat);
      await AppServices.instance.guard.emergencyEntry(
        flatId: flatId,
        name: _name.text.trim(),
        purpose: _purpose,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Emergency entry recorded.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Emergency entry',
    subtitle: 'Record emergency services entering the society',
    body: FutureBuilder(
      future: _directory,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: '${snapshot.error}',
            onRetry: () {
              setState(() => _directory = GateDirectory.load());
            },
          );
        }
        final directory = snapshot.data;
        if (directory == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text('This records entry without resident approval.'),
              const SizedBox(height: 12),
              TowerFlatSelector(
                flatsByTower: directory.flatsByTower,
                onSelectionChanged: (_, flat) => setState(() => _flat = flat),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Emergency service',
                ),
                items: const ['Ambulance', 'Fire service', 'Police']
                    .map(
                      (service) => DropdownMenuItem(
                        value: service,
                        child: Text(service),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _purpose = value!),
              ),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Name or crew'),
                validator: (value) =>
                    (value ?? '').trim().length < 2 ? 'Enter a name.' : null,
              ),
              TextFormField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for emergency entry',
                ),
                validator: (value) => (value ?? '').trim().length < 5
                    ? 'Enter at least five characters.'
                    : null,
              ),
              FilledButton(
                onPressed: _busy || _flat == null
                    ? null
                    : () => _record(directory),
                child: const Text('Record emergency entry'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
