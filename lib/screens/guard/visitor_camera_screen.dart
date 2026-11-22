import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habitoliving_shared/services/media_service.dart';

import 'tower_flat_selector.dart';

/// Takes a still photo inside the guard activity so the form stays mounted.
class VisitorCameraScreen extends StatefulWidget {
  const VisitorCameraScreen({super.key});

  @override
  State<VisitorCameraScreen> createState() => _VisitorCameraScreenState();
}

class _VisitorCameraScreenState extends State<VisitorCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  PickedFile? _photo;
  Future<void> _cameraWork = Future.value();
  bool _foreground = true;
  bool _taking = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A permission dialog can briefly make the app inactive during startup.
    if (state == AppLifecycleState.inactive) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foreground = false;
    _sync();
    super.dispose();
  }

  void _sync() {
    // Serialize open, capture and close, including during rapid pause/resume.
    final closing = !_foreground;
    _cameraWork = _cameraWork.then((_) => _syncCamera(closing: closing));
  }

  Future<void> _syncCamera({bool closing = false}) async {
    if (closing || !mounted || !_foreground || _photo != null) {
      final camera = _camera;
      _camera = null;
      if (camera == null) return;
      if (mounted && _foreground) setState(() {});
      await _release(camera);
      return;
    }
    if (_camera != null) return;
    CameraController? opening;
    try {
      setState(() => _error = null);
      final cameras = await availableCameras();
      if (!mounted || !_foreground) return;
      if (cameras.isEmpty) {
        throw const _NoCamera();
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      opening = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await opening.initialize();
      if (!mounted || !_foreground) return;
      final initialized = opening;
      setState(() => _camera = initialized);
      opening = null;
    } catch (error, stack) {
      _report('starting the visitor camera', error, stack);
      if (mounted && _foreground) setState(() => _error = error);
    } finally {
      if (opening != null) await _release(opening);
    }
  }

  Future<void> _release(CameraController camera) async {
    try {
      await camera.dispose();
    } catch (error, stack) {
      _report('closing the visitor camera', error, stack);
    }
  }

  void _takePhoto() {
    if (_taking || !_foreground || _camera == null) return;
    setState(() {
      _taking = true;
      _error = null;
    });
    _cameraWork = _cameraWork.then((_) async {
      try {
        final camera = _camera;
        if (!mounted || !_foreground || camera == null) return;
        final file = await camera.takePicture();
        final bytes = await _readShot(file);
        if (bytes.isEmpty) {
          throw MediaException('The camera returned an empty photo.');
        }
        if (!mounted) return;
        setState(() {
          _photo = PickedFile(
            name: 'visitor.jpg',
            bytes: bytes,
            mimeType: 'image/jpeg',
            sizeBytes: bytes.length,
          );
        });
        await _syncCamera();
      } catch (error, stack) {
        _report('taking the visitor photo', error, stack);
        if (mounted) setState(() => _error = error);
      } finally {
        if (mounted) setState(() => _taking = false);
      }
    });
  }

  Future<Uint8List> _readShot(XFile file) async {
    try {
      return await file.readAsBytes();
    } finally {
      if (!kIsWeb) {
        try {
          await File(file.path).delete();
        } on FileSystemException catch (error, stack) {
          _report('removing the temporary visitor photo', error, stack);
        }
      }
    }
  }

  void _report(String action, Object error, StackTrace stack) {
    debugPrint('Visitor camera: $action (${error.runtimeType})');
    debugPrintStack(stackTrace: stack);
  }

  String _errorText(bool hindi, Object error) {
    if (error is _NoCamera) {
      return gateText(
        hindi,
        'No camera is available.',
        'कोई कैमरा उपलब्ध नहीं है।',
      );
    }
    if (error is CameraException && error.code.startsWith('CameraAccess')) {
      return gateText(
        hindi,
        'Allow camera access in your device settings and try again.',
        'डिवाइस की सेटिंग में कैमरा की अनुमति देकर फिर कोशिश करें।',
      );
    }
    return gateText(
      hindi,
      'Could not take a photo. Try again.',
      'फ़ोटो नहीं ली जा सकी। फिर कोशिश करें।',
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: gateIsHindi,
    builder: (context, hindi, _) {
      final photo = _photo;
      final camera = _camera;
      final error = _error;
      return GatePage(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 6, 16, 5),
              child: GateHeader(
                title: gateText(hindi, 'Visitor photo', 'आगंतुक की फ़ोटो'),
                language: gateIsHindi,
              ),
            ),
            Expanded(
              child: switch ((photo, camera, error)) {
                (final photo?, _, _) => Image.memory(
                  photo.bytes,
                  fit: BoxFit.contain,
                ),
                (_, _, final error?) => GateStatusMessage(
                  icon: Icons.no_photography_outlined,
                  title: gateText(
                    hindi,
                    'Camera unavailable',
                    'कैमरा उपलब्ध नहीं है',
                  ),
                  message: _errorText(hindi, error),
                  action: GateButton(
                    label: gateText(hindi, 'Try again', 'फिर कोशिश करें'),
                    onPressed: () {
                      setState(() => _error = null);
                      _cameraWork = _cameraWork.then((_) async {
                        await _syncCamera(closing: true);
                        await _syncCamera();
                      });
                    },
                  ),
                ),
                (_, final camera?, _) => Center(child: CameraPreview(camera)),
                _ => const Center(
                  child: CircularProgressIndicator(color: GateStyle.green),
                ),
              },
            ),
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photo != null)
                TextButton(
                  onPressed: _taking
                      ? null
                      : () {
                          setState(() => _photo = null);
                          _sync();
                        },
                  child: Text(
                    gateText(hindi, 'Retake photo', 'फिर से फ़ोटो लें'),
                  ),
                ),
              GateButton(
                label: photo == null
                    ? gateText(hindi, 'Take photo', 'फ़ोटो लें')
                    : gateText(hindi, 'Use photo', 'फ़ोटो इस्तेमाल करें'),
                icon: photo == null
                    ? Icons.camera_alt_outlined
                    : Icons.check_rounded,
                busy: _taking,
                onPressed: photo != null
                    ? () => Navigator.of(context).pop(photo)
                    : camera != null && error == null && _foreground
                    ? _takePhoto
                    : null,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NoCamera implements Exception {
  const _NoCamera();
}
