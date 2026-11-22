import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:habitoliving_shared/services/media_service.dart';

import 'tower_flat_selector.dart';

enum VisitorPurpose {
  guest('Guest', 'मेहमान', Icons.group_rounded),
  cab('Cab / Auto', 'कैब / ऑटो', Icons.local_taxi_rounded),
  service('Service', 'सेवा', Icons.build_rounded),
  other('Other', 'अन्य', Icons.more_horiz_rounded);

  const VisitorPurpose(this.english, this.hindi, this.icon);
  final String english;
  final String hindi;
  final IconData icon;
}

class VisitorSubmission {
  const VisitorSubmission({
    required this.tower,
    required this.flat,
    required this.name,
    required this.purpose,
    required this.photo,
    required this.usesMockPhoto,
    this.phone,
    this.vehicle,
  });

  final String tower;
  final String flat;
  final String name;
  final VisitorPurpose purpose;
  final ImageProvider<Object>? photo;
  final bool usesMockPhoto;
  final String? phone;
  final String? vehicle;
}

class RegisterVisitorScreen extends StatefulWidget {
  const RegisterVisitorScreen({
    super.key,
    this.flatsByTower = const {},
    this.language,
    this.onBack,
    this.onCapturePhoto,
    this.onSubmit,
    this.isSubmitting = false,
  });

  final Map<String, List<String>> flatsByTower;
  final ValueNotifier<bool>? language;
  final VoidCallback? onBack;

  /// Return a photo for preview, or null if the guard cancels.
  final Future<ImageProvider<Object>?> Function()? onCapturePhoto;
  final ValueChanged<VisitorSubmission>? onSubmit;
  final bool isSubmitting;

  @override
  State<RegisterVisitorScreen> createState() => _RegisterVisitorScreenState();
}

class _RegisterVisitorScreenState extends State<RegisterVisitorScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  var _purpose = VisitorPurpose.guest;
  var _optionalOpen = false;
  var _capturing = false;
  var _mockPhoto = false;
  ImageProvider<Object>? _photo;
  String? _tower;
  String? _flat;

  bool get _hasPhoto => _photo != null || _mockPhoto;
  bool get _ready =>
      _tower != null &&
      _flat != null &&
      _name.text.trim().isNotEmpty &&
      _hasPhoto;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || widget.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final capture = widget.onCapturePhoto;
    if (capture == null) {
      setState(() => _mockPhoto = true);
      return;
    }
    setState(() => _capturing = true);
    try {
      final photo = await capture();
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _mockPhoto = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      final hindi = (widget.language ?? gateIsHindi).value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is MediaException && !hindi
                ? error.message
                : gateText(
                    hindi,
                    'Could not take photo',
                    'फ़ोटो नहीं ली जा सकी',
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _submit() {
    if (!_ready || _capturing || widget.isSubmitting) return;
    FocusScope.of(context).unfocus();
    String? optional(TextEditingController value) {
      final text = value.text.trim();
      return text.isEmpty ? null : text;
    }

    widget.onSubmit?.call(
      VisitorSubmission(
        tower: _tower!,
        flat: _flat!,
        name: _name.text.trim(),
        purpose: _purpose,
        photo: _photo,
        usesMockPhoto: _mockPhoto,
        phone: optional(_phone),
        vehicle: optional(_vehicle),
      ),
    );
  }

  InputDecoration _field(String label, IconData icon, {bool hint = false}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: GateStyle.line),
    );
    return InputDecoration(
      hintText: hint ? label : null,
      labelText: hint ? null : label,
      prefixIcon: Icon(icon, color: GateStyle.muted),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: GateStyle.green, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.language ?? gateIsHindi;
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hindi, _) {
        String t(String en, String hi) => gateText(hindi, en, hi);
        final required = t('(Required)', '(ज़रूरी)');
        return GatePage(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 6, 16, 5),
                child: GateHeader(
                  title: t('Register a Visitor', 'आगंतुक दर्ज करें'),
                  language: notifier,
                  onBack: widget.onBack,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const Divider(color: GateStyle.line, height: 15),
                    GateSection(
                      Icons.apartment_rounded,
                      t('Select Tower & Flat', 'टावर और फ़्लैट चुनें'),
                    ),
                    TowerFlatSelector(
                      flatsByTower: widget.flatsByTower,
                      language: notifier,
                      onSelectionChanged: (tower, flat) => setState(() {
                        _tower = tower;
                        _flat = flat;
                      }),
                    ),
                    const Divider(color: GateStyle.line, height: 28),
                    GateSection(
                      Icons.photo_camera_rounded,
                      t('Visitor Photo', 'आगंतुक की फ़ोटो'),
                      suffix: required,
                    ),
                    _photoCard(hindi),
                    const Divider(color: GateStyle.line, height: 27),
                    GateSection(
                      Icons.person_rounded,
                      t('Visitor Name', 'आगंतुक का नाम'),
                      suffix: required,
                    ),
                    TextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: _field(
                        t(
                          "Enter visitor's full name",
                          'आगंतुक का पूरा नाम लिखें',
                        ),
                        Icons.person_outline,
                        hint: true,
                      ),
                    ),
                    const Divider(color: GateStyle.line, height: 27),
                    GateSection(
                      Icons.sell_rounded,
                      t('Purpose', 'आने का कारण'),
                    ),
                    Wrap(
                      spacing: 5,
                      runSpacing: 6,
                      children: [
                        for (final purpose in VisitorPurpose.values)
                          _purposeChip(purpose, hindi),
                      ],
                    ),
                    const Divider(color: GateStyle.line, height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_optionalOpen) FocusScope.of(context).unfocus();
                        setState(() => _optionalOpen = !_optionalOpen);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _optionalOpen ? Icons.remove : Icons.add,
                              color: GateStyle.green,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _optionalOpen
                                    ? t(
                                        'Hide optional fields',
                                        'वैकल्पिक जानकारी छिपाएँ',
                                      )
                                    : t(
                                        'Add phone or vehicle number (optional)',
                                        'फ़ोन या गाड़ी नंबर जोड़ें (वैकल्पिक)',
                                      ),
                                style: const TextStyle(
                                  color: GateStyle.green,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              _optionalOpen
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: GateStyle.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: _optionalOpen
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _phone,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      decoration: _field(
                                        t('Phone Number', 'फ़ोन नंबर'),
                                        Icons.phone_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _vehicle,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      textInputAction: TextInputAction.done,
                                      decoration: _field(
                                        t('Vehicle Number', 'गाड़ी नंबर'),
                                        Icons.directions_car_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const Divider(color: GateStyle.line, height: 15),
                  ],
                ),
              ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
            child: GateButton(
              label: t('Send for Approval', 'मंज़ूरी के लिए भेजें'),
              icon: Icons.send_outlined,
              busy: widget.isSubmitting,
              onPressed: _ready && !_capturing && widget.onSubmit != null
                  ? _submit
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _purposeChip(VisitorPurpose purpose, bool hindi) {
    final selected = _purpose == purpose;
    final color = selected ? Colors.white : GateStyle.ink;
    return GateTile(
      selected: selected,
      color: selected ? GateStyle.green : GateStyle.sand,
      onTap: () => setState(() => _purpose = purpose),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(purpose.icon, color: color, size: 15.6),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  gateText(hindi, purpose.english, purpose.hindi),
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoCard(bool hindi) {
    final photo = _photo;
    final label = _mockPhoto
        ? gateText(
            hindi,
            'Sample photo • Tap to retake',
            'नमूना फ़ोटो • फिर से लें',
          )
        : photo != null
        ? gateText(hindi, 'Tap to retake photo', 'फिर से फ़ोटो लें')
        : gateText(
            hindi,
            'Tap to Take Visitor Photo',
            'आगंतुक की फ़ोटो लेने के लिए टैप करें',
          );
    return CustomPaint(
      foregroundPainter: const _DashedBorder(),
      child: GateTile(
        color: GateStyle.mint,
        onTap: _capturing || widget.isSubmitting ? null : _capture,
        child: Column(
          children: [
            if (photo != null)
              Image(
                image: photo,
                height: 108,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 108,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 23),
                child: _capturing
                    ? const SizedBox.square(
                        dimension: 66,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: GateStyle.green,
                          ),
                        ),
                      )
                    : Icon(
                        _mockPhoto
                            ? Icons.account_box_rounded
                            : Icons.photo_camera_rounded,
                        size: 60.7,
                        color: GateStyle.green,
                      ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 23),
              child: Text(
                _capturing
                    ? gateText(hindi, 'Opening camera…', 'कैमरा खुल रहा है…')
                    : label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GateStyle.green,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.8),
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = GateStyle.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in outline.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 6, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder oldDelegate) => false;
}
