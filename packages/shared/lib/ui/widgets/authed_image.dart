import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/app_services.dart';
import '../icons.dart';
import '../tokens.dart';

/// Renders a protected image stored behind `/files/{id}`.
///
/// A plain [Image.network] would 401, because the bytes require the bearer
/// token. This widget fetches them through [FilesApi.fetch] (which attaches
/// the token and transparently refreshes it) and decodes them in memory.
///
/// The result is cached by [fileId] so a card that rebuilds on every socket
/// tick does not re-download the photo. Use [cacheKey] to bust the cache when
/// the same id is replaced.
class AuthedImage extends StatefulWidget {
  const AuthedImage({
    super.key,
    required this.fileId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  final String fileId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Shown while loading and when the bytes cannot be fetched or decoded.
  final Widget? fallback;

  @override
  State<AuthedImage> createState() => _AuthedImageState();
}

class _AuthedImageState extends State<AuthedImage> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _bytes = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = _cache[widget.fileId];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _bytes = cached;
        _loading = false;
      });
      return;
    }
    try {
      final data = await AppServices.instance.files.fetch(widget.fileId);
      final bytes = Uint8List.fromList(data);
      _cache[widget.fileId] = bytes;
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _fallback() =>
      widget.fallback ??
      Container(
        width: widget.width,
        height: widget.height,
        color: Tokens.surfaceSunken,
        alignment: Alignment.center,
        child: AppIcon(
          Icons2.visitors,
          size: IconSize.row,
          color: Tokens.inkMuted,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    Widget child;
    if (bytes != null) {
      child = Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    } else if (_loading) {
      child = Container(
        width: widget.width,
        height: widget.height,
        color: Tokens.surfaceSunken,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      child = _fallback();
    }
    final radius = widget.borderRadius;
    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: child);
    }
    return child;
  }
}

/// Clears the in-memory photo cache. Exposed for sign-out and tests.
void clearAuthedImageCache() => _AuthedImageState._cache.clear();