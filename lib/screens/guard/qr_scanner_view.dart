import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A single-purpose QR scanner for the gate's "Verify a pass" screen.
///
/// The scanner manages the camera when the preview comes and goes.
/// Duplicate detections of the same code within two seconds are ignored: the
/// scanner emits a frame several times while a code is held still, and a second
/// verify call would be rejected by the backend anyway.
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onCode,
    this.label = 'QR code',
  });

  final ValueChanged<String> onCode;
  final String label;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  String? _lastCode;
  DateTime? _lastAt;

  void _handle(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      final now = DateTime.now();
      final last = _lastAt;
      if (raw == _lastCode &&
          last != null &&
          now.difference(last).inSeconds < 2) {
        continue;
      }
      _lastCode = raw;
      _lastAt = now;
      widget.onCode(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: _handle,
      errorBuilder: (context, error) {
        return ColoredBox(
          color: const Color(0xFF145338),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.no_photography_rounded,
                    color: Colors.white,
                    size: 51.5,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Camera unavailable. Check camera permission and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      placeholderBuilder: (context) => const ColoredBox(
        color: Color(0xFF145338),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
