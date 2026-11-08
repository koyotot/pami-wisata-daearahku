import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../data/business_repository.dart';
import '../services/auth_session.dart';

/// Loads a Laravel destination image through the API client, so it works on the Android
/// emulator (Host header handling) and for admin-only inactive destinations.
///
/// [imageUrl] is the relative `image_url` from the API. When [adminGuid] is set the
/// authorized admin media endpoint is used instead of the public one.
class ApiImage extends StatefulWidget {
  final String? imageUrl;
  final String? adminGuid;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context)? placeholder;
  final BusinessRepository? repository;

  const ApiImage({
    super.key,
    required this.imageUrl,
    this.adminGuid,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.repository,
  });

  @override
  State<ApiImage> createState() => _ApiImageState();

  /// Clears cached bytes (call on logout/account switch).
  static void clearCache() => _ApiImageState._cache.clear();

  static Future<void> prefetch(String url, BusinessRepository repository,
      {String? adminGuid}) async {
    final generation = repository.api.session.sessionGeneration;
    final key = '${adminGuid ?? 'public'}|$url';
    if (_ApiImageState._cache.containsKey(key)) return;
    try {
      final result = adminGuid == null
          ? await repository.imageBytes(url)
          : await repository.adminImageBytes(adminGuid, url);
      if (generation != repository.api.session.sessionGeneration ||
          !result.contentType.startsWith('image/')) {
        return;
      }
      if (_ApiImageState._cache.length >= _ApiImageState._maxEntries) {
        _ApiImageState._cache.remove(_ApiImageState._cache.keys.first);
      }
      _ApiImageState._cache[key] = result.bytes;
    } catch (_) {/* A visible image provides retry when prefetch fails. */}
  }
}

class _ApiImageState extends State<ApiImage> {
  // The URL carries a version (`?v=`), so a replaced image never hits a stale entry.
  static final Map<String, Uint8List> _cache = {};
  static const _maxEntries = 60;

  static bool _listening = false;

  Uint8List? _bytes;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (!_listening) {
      _listening = true;
      // Logout or account switch must not leave admin-only pictures readable.
      AuthSession.instance.sessionChanges.addListener(_cache.clear);
    }
    _load();
  }

  @override
  void didUpdateWidget(ApiImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl || old.adminGuid != widget.adminGuid) {
      _load();
    }
  }

  String get _cacheKey => '${widget.adminGuid ?? 'public'}|${widget.imageUrl}';

  Future<void> _load() async {
    final url = widget.imageUrl;
    final request = ++_request;
    final cacheKey = _cacheKey;
    if (url == null || url.isEmpty) {
      setState(() {
        _bytes = null;
        _failed = false;
      });
      return;
    }
    final cached = _cache[cacheKey];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _failed = false;
      });
      return;
    }
    setState(() {
      _bytes = null;
      _failed = false;
    });
    try {
      final repository = widget.repository ?? BusinessRepository();
      final generation = repository.api.session.sessionGeneration;
      final admin = widget.adminGuid;
      final response = admin == null
          ? await repository.imageBytes(url)
          : await repository.adminImageBytes(admin, url);
      if (generation != repository.api.session.sessionGeneration) return;
      if (!response.contentType.startsWith('image/')) {
        throw const ApiException('Respons gambar tidak valid.');
      }
      if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first);
      if (!mounted || request != _request) return;
      _cache[cacheKey] = response.bytes;
      // Ignore results for a different URL or a disposed widget.
      if (!mounted || request != _request) return;
      setState(() => _bytes = response.bytes);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      final decodeWidth = (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(1, 2048);
      return Image.memory(bytes,
          cacheWidth: decodeWidth,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _fallback(context));
    }
    if (_failed || widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _fallback(context);
    }
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))));
  }

  Widget _fallback(BuildContext context) => GestureDetector(
      onTap: _failed ? _load : null,
      child: widget.placeholder?.call(context) ??
          SizedBox(
              width: widget.width,
              height: widget.height,
              child:
                  const Center(child: Icon(PhosphorIconsRegular.imageBroken))));
}
