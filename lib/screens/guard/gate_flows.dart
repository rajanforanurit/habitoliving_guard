import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/media_service.dart';
import 'qr_scanner_view.dart';
import 'register_delivery_screen.dart';
import 'register_visitor_screen.dart';
import 'tower_flat_selector.dart';
import 'verify_pass_screen.dart';
import 'visitor_camera_screen.dart';

/// Loads the gate directory once per society until the layout is refreshed.
class GateDirectory {
  GateDirectory._();

  static (String?, Future<SocietyPropertyInfo>)? _cache;

  static Future<SocietyPropertyInfo> load() async {
    final services = AppServices.instance;
    final societyId = services.session.activeSocietyId;
    final cached = _cache;
    if (cached != null && cached.$1 == societyId) return cached.$2;

    final request = services.guard.societyInfo().then((info) {
      if (info.isEmpty) {
        throw StateError(
          'No towers or flats are configured for this society yet. Ask the '
          'society admin to set the property layout.',
        );
      }
      return info;
    });
    _cache = (societyId, request);
    try {
      return await request;
    } catch (_) {
      if (identical(_cache?.$2, request)) clear();
      rethrow;
    }
  }

  static void clear() => _cache = null;
}

Future<String> resolveGateFlatId(
  SocietyPropertyInfo directory,
  String label,
) async {
  final services = AppServices.instance;
  if (directory.societyId != services.session.activeSocietyId) {
    throw StateError(
      'The active society changed. Reopen the registration form.',
    );
  }
  final savedId = directory.flatIds[label];
  if (savedId != null) return savedId;

  // Older API responses only provide labels. A partial match can send the
  // approval request to a different flat, so require a unique exact match.
  final matches = await services.guard.lookupFlat(label);
  final exact = matches.where((flat) => flat['label'] == label).toList();
  if (exact.length == 1) {
    final id = exact.single['id'];
    if (id is String && id.isNotEmpty) return id;
  }
  throw StateError('Flat "$label" was not found in this society.');
}

String _visitorType(VisitorPurpose purpose) => switch (purpose) {
  VisitorPurpose.guest => 'GUEST',
  VisitorPurpose.cab => 'CAB_DRIVER',
  VisitorPurpose.service => 'SERVICE_PROVIDER',
  VisitorPurpose.other => 'OTHER',
};

String _deliveryType(DeliveryCategory category) => switch (category) {
  DeliveryCategory.grocery => 'GROCERY',
  DeliveryCategory.parcel => 'PARCEL',
  DeliveryCategory.food => 'FOOD',
  DeliveryCategory.document => 'COURIER',
  DeliveryCategory.other => 'OTHER',
};

/// Opens the new visitor form. Pops with the created visitor when the request
/// is in, or null when the guard backs out.
Future<Visitor?> openRegisterVisitor(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return Navigator.of(context).push<Visitor>(
    MaterialPageRoute<Visitor>(
      builder: (_) => _VisitorRegisterFlow(onChanged: onChanged),
    ),
  );
}

/// Opens the new delivery form. Pops with the registered delivery, or null when
/// the guard backs out.
Future<Delivery?> openRegisterDelivery(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return Navigator.of(context).push<Delivery>(
    MaterialPageRoute<Delivery>(
      builder: (_) => _DeliveryFlow(onChanged: onChanged),
    ),
  );
}

/// Opens the new pass-verification screen. Pops with the verified visitor.
Future<Visitor?> openVerifyPass(BuildContext context) {
  return Navigator.of(context).push<Visitor>(
    MaterialPageRoute<Visitor>(builder: (_) => const _VerifyPassFlow()),
  );
}

/// The entry or exit action for an approved or checked-in visitor.
Future<void> showVisitorGateAction(
  BuildContext context,
  Visitor visitor, {
  required VoidCallback onChanged,
  bool passVerified = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GateStyle.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _VisitorGateActionSheet(
      visitor: visitor,
      onChanged: onChanged,
      passVerified: passVerified,
    ),
  );
}

// ---------------------------------------------------------------- visitor

class _VisitorRegisterFlow extends StatefulWidget {
  const _VisitorRegisterFlow({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_VisitorRegisterFlow> createState() => _VisitorRegisterFlowState();
}

class _VisitorRegisterFlowState extends State<_VisitorRegisterFlow> {
  SocietyPropertyInfo? _directory;
  Object? _error;
  PickedFile? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final directory = await GateDirectory.load();
      if (!mounted) return;
      setState(() {
        _directory = directory;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<ImageProvider<Object>?> _capture() async {
    final picked = await Navigator.of(context).push<PickedFile>(
      MaterialPageRoute<PickedFile>(
        builder: (_) => const VisitorCameraScreen(),
      ),
    );
    if (!mounted || picked == null) return null;

    // A device can capture a usable picture even if its compression plugin
    // fails. Keep the original whenever it already fits the upload limit.
    var photo = picked;
    try {
      photo = await AppServices.instance.media.compressForUpload(picked);
    } on Exception {
      debugPrint(
        'Visitor photo compression failed. Checking the original size.',
      );
    }
    if (!mounted) return null;
    if (photo.tooLarge) {
      throw MediaException('The photo is too large. Please retake it.');
    }
    _photo = photo;
    return MemoryImage(photo.bytes);
  }

  Future<void> _submit(VisitorSubmission submission) async {
    if (_busy) return;
    if (submission.name.trim().length < 2) {
      showMessage(context, 'Enter the visitor’s full name.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final flatId = await resolveGateFlatId(_directory!, submission.flat);
      final photo = _photo;
      String? photoFileId;
      if (photo != null) {
        photoFileId = await AppServices.instance.media.upload(
          photo,
          purpose: UploadPurpose.visitor,
          // SOCIETY so the resident can see the face before deciding.
          visibility: 'SOCIETY',
        );
      }
      final visitor = await AppServices.instance.guard.registerVisitor(
        name: submission.name,
        flatId: flatId,
        phone: submission.phone,
        visitorType: _visitorType(submission.purpose),
        purpose: submission.purpose.english,
        vehicleNumber: submission.vehicle,
        photoFileId: photoFileId,
      );
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop(visitor);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;
    if (directory == null) {
      return GatePage(
        body: GateStatusMessage(
          icon: _error == null
              ? Icons.hourglass_top_rounded
              : Icons.error_rounded,
          title: _error == null
              ? 'Loading the flat list'
              : 'Could not load flats',
          message: _error == null
              ? 'Fetching the society layout.'
              : _directoryErrorText(_error),
          action: _error == null
              ? null
              : _FlowAction(
                  label: 'Try again',
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  },
                ),
        ),
      );
    }
    return RegisterVisitorScreen(
      flatsByTower: directory.flatsByTower,
      language: gateIsHindi,
      isSubmitting: _busy,
      onCapturePhoto: _capture,
      onSubmit: _submit,
    );
  }
}

// --------------------------------------------------------------- delivery

class _DeliveryFlow extends StatefulWidget {
  const _DeliveryFlow({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_DeliveryFlow> createState() => _DeliveryFlowState();
}

class _DeliveryFlowState extends State<_DeliveryFlow> {
  SocietyPropertyInfo? _directory;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final directory = await GateDirectory.load();
      if (!mounted) return;
      setState(() {
        _directory = directory;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _submit(DeliverySubmission submission) async {
    if (_busy) return;
    final company = submission.brand == DeliveryBrand.other
        ? (submission.courierName ?? '').trim()
        : submission.brand.label;
    if (company.length < 2) {
      showMessage(
        context,
        'Enter the courier or company name (at least two characters).',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final flatId = await resolveGateFlatId(_directory!, submission.flat);
      final delivery = await AppServices.instance.guard.registerDelivery(
        flatId: flatId,
        company: company,
        agentName: company,
        deliveryType: _deliveryType(submission.category),
      );
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop(delivery);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;
    if (directory == null) {
      return GatePage(
        body: GateStatusMessage(
          icon: _error == null
              ? Icons.hourglass_top_rounded
              : Icons.error_rounded,
          title: _error == null
              ? 'Loading the flat list'
              : 'Could not load flats',
          message: _error == null
              ? 'Fetching the society layout.'
              : _directoryErrorText(_error),
          action: _error == null
              ? null
              : _FlowAction(
                  label: 'Try again',
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  },
                ),
        ),
      );
    }
    return RegisterDeliveryScreen(
      flatsByTower: directory.flatsByTower,
      language: gateIsHindi,
      isSubmitting: _busy,
      onSubmit: _submit,
    );
  }
}

String _directoryErrorText(Object? error) =>
    error is StateError ? error.message : '$error';

// ----------------------------------------------------------------- verify

class _VerifyPassFlow extends StatefulWidget {
  const _VerifyPassFlow();

  @override
  State<_VerifyPassFlow> createState() => _VerifyPassFlowState();
}

class _VerifyPassFlowState extends State<_VerifyPassFlow> {
  bool _busy = false;

  Future<void> _verify(String raw) async {
    final code = raw.trim();
    if (_busy || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final isCode = RegExp(r'^\d{6}$').hasMatch(code);
      final visitor = await AppServices.instance.guard.verifyPass(
        isCode ? code : '',
        qrToken: isCode ? null : code,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(visitor);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VerifyPassScreen(
      language: gateIsHindi,
      initialCode: '',
      isVerifying: _busy,
      onVerify: _verify,
      scannerBuilder: (_) => QrScannerView(onCode: _verify),
    );
  }
}

class _VisitorGateActionSheet extends StatefulWidget {
  const _VisitorGateActionSheet({
    required this.visitor,
    required this.onChanged,
    required this.passVerified,
  });

  final Visitor visitor;
  final VoidCallback onChanged;
  final bool passVerified;

  @override
  State<_VisitorGateActionSheet> createState() =>
      _VisitorGateActionSheetState();
}

class _VisitorGateActionSheetState extends State<_VisitorGateActionSheet> {
  bool _busy = false;

  Future<void> _recordMovement() async {
    if (_busy) return;
    final visitor = widget.visitor;
    final guard = AppServices.instance.guard;
    setState(() => _busy = true);
    try {
      if (visitor.isOnPremises) {
        await guard.recordExit(visitor.id);
      } else {
        await guard.recordEntry(visitor.id);
      }
      if (!mounted) return;
      widget.onChanged();
      showMessage(
        context,
        visitor.isOnPremises ? 'Exit recorded.' : 'Entry recorded.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitor;
    final checkedIn = visitor.isOnPremises;
    final canRecord =
        visitor.status == VisitorStatusValue.approved ||
        (checkedIn && !widget.passVerified);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: GateStyle.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: GateStyle.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.passVerified
                        ? (checkedIn
                              ? 'Pass is valid — already inside'
                              : 'Pass is valid')
                        : visitor.status.label,
                    style: const TextStyle(
                      color: GateStyle.green,
                      fontSize: 18.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                visitor.name,
                if (visitor.flatLabel != null) visitor.flatLabel!,
                if (visitor.purpose != null) visitor.purpose!,
                if (visitor.phone != null) Fmt.phone(visitor.phone),
              ].join(' · '),
              style: const TextStyle(color: GateStyle.muted, fontSize: 13.8),
            ),
            const SizedBox(height: 20),
            if (canRecord) ...[
              GateButton(
                label: checkedIn ? 'Record exit' : 'Record entry',
                icon: checkedIn ? Icons.logout_rounded : Icons.login_rounded,
                busy: _busy,
                onPressed: _recordMovement,
              ),
              const SizedBox(height: 10),
            ],
            GateButton(
              label: 'Done',
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowAction extends StatelessWidget {
  const _FlowAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GateButton(
    label: label,
    icon: Icons.refresh_rounded,
    onPressed: onPressed,
  );
}
