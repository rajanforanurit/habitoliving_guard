import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';

import 'tower_flat_selector.dart';

class MaidAttendanceScreen extends StatefulWidget {
  const MaidAttendanceScreen({super.key, this.onRecorded});

  final VoidCallback? onRecorded;

  @override
  State<MaidAttendanceScreen> createState() => _MaidAttendanceScreenState();
}

class _MaidAttendanceScreenState extends State<MaidAttendanceScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  ({String name, DateTime date, bool alreadyMarked})? _attendance;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _attendance = null;
    });
    try {
      final result = await AppServices.instance.guard.markMaidAttendance(
        _code.text,
      );
      if (!mounted) return;
      _code.clear();
      setState(() => _attendance = result);
      widget.onRecorded?.call();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: gateIsHindi,
    builder: (context, hindi, _) {
      String t(String en, String hi) => gateText(hindi, en, hi);
      final attendance = _attendance;
      return GatePage(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GateHeader(
              title: t('Maid attendance', 'मेड उपस्थिति'),
              language: gateIsHindi,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              focusNode: _focus,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: t(
                  'Six-digit attendance code',
                  'छह अंकों का उपस्थिति कोड',
                ),
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {
                _error = null;
                _attendance = null;
              }),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            GateButton(
              label: t('Mark present', 'उपस्थिति दर्ज करें'),
              icon: Icons.how_to_reg_rounded,
              busy: _busy,
              onPressed: _code.text.length == 6 ? _submit : null,
            ),
            if (attendance != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: GateStatusMessage(
                  icon: Icons.check_circle_outline_rounded,
                  title: attendance.alreadyMarked
                      ? t(
                          'Attendance already marked',
                          'उपस्थिति पहले से दर्ज है',
                        )
                      : t('Attendance recorded', 'उपस्थिति दर्ज हुई'),
                  message:
                      '${attendance.name} · ${Fmt.dateFull(attendance.date)}',
                  action: TextButton(
                    onPressed: _focus.requestFocus,
                    child: Text(t('Enter another code', 'दूसरा कोड डालें')),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
