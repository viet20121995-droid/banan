import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/internal_api.dart';

/// Tiny in-memory cache so re-builds don't refetch the same evidence bytes.
class _ByteCache {
  static final Map<String, Uint8List> _map = {};
  static Uint8List? get(String key) => _map[key];
  static void put(String key, Uint8List bytes) {
    if (_map.length > 100) _map.remove(_map.keys.first);
    _map[key] = bytes;
  }
}

Widget _frame(Widget child, double size) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: size, height: size, child: child),
    );

Widget _placeholder(double size, {bool broken = false}) => _frame(
      ColoredBox(
        color: Colors.black12,
        child: Icon(broken ? Icons.broken_image_outlined : Icons.image_outlined, size: 20),
      ),
      size,
    );

/// Evidence thumbnail for the ADMIN app — bytes stream through the
/// Bearer-authenticated /internal/files endpoint (evidence is never on a
/// public URL, so Image.network cannot render it).
class PrivateImage extends ConsumerWidget {
  const PrivateImage({required this.name, this.size = 84, super.key});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = _ByteCache.get('admin:$name');
    if (cached != null) return _frame(Image.memory(cached, fit: BoxFit.cover), size);
    return FutureBuilder(
      future: ref.read(internalApiProvider).fileBytes(name),
      builder: (context, snapshot) {
        final bytes = snapshot.data?.valueOrNull;
        if (bytes == null) {
          return _placeholder(size, broken: snapshot.connectionState == ConnectionState.done);
        }
        _ByteCache.put('admin:$name', bytes);
        return _frame(Image.memory(bytes, fit: BoxFit.cover), size);
      },
    );
  }
}

/// Evidence thumbnail for the PUBLIC MS form — token-guarded POST fetch.
class PublicEvidenceImage extends ConsumerWidget {
  const PublicEvidenceImage({
    required this.token,
    required this.name,
    this.size = 84,
    super.key,
  });
  final String token;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = _ByteCache.get('pub:$name');
    if (cached != null) return _frame(Image.memory(cached, fit: BoxFit.cover), size);
    return FutureBuilder(
      future: ref.read(internalPublicApiProvider).fileBytes(token, name),
      builder: (context, snapshot) {
        final bytes = snapshot.data?.valueOrNull;
        if (bytes == null) {
          return _placeholder(size, broken: snapshot.connectionState == ConnectionState.done);
        }
        _ByteCache.put('pub:$name', bytes);
        return _frame(Image.memory(bytes, fit: BoxFit.cover), size);
      },
    );
  }
}
