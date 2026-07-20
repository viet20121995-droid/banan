import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-image carousel picker used by the thread editor. The first image is
/// the cover. Parent owns the list and rebuilds with a new [urls] after
/// [onChanged] fires (add / remove / reorder).
class GalleryImagePicker extends ConsumerStatefulWidget {
  const GalleryImagePicker({
    required this.urls,
    required this.onChanged,
    this.maxImages = 10,
    super.key,
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final int maxImages;

  @override
  ConsumerState<GalleryImagePicker> createState() =>
      _GalleryImagePickerState();
}

class _GalleryImagePickerState extends ConsumerState<GalleryImagePicker> {
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final remaining = widget.maxImages - widget.urls.length;
    if (remaining <= 0) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    final files = picked?.files
            .where((f) => f.bytes != null)
            .take(remaining)
            .toList() ??
        const [];
    if (files.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final repo = ref.read(catalogRepositoryProvider);
    final added = <String>[];
    for (final file in files) {
      final res = await repo.uploadImage(
        bytes: file.bytes!,
        filename: file.name,
        mimeType: _mimeFor(file.extension),
      );
      res.when(
        success: (uploaded) => added.add(uploaded.url),
        failure: (f) => _error = 'Tải ảnh thất bại: ${authFailureMessage(f)}',
      );
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (added.isNotEmpty) {
      widget.onChanged([...widget.urls, ...added]);
    }
  }

  void _removeAt(int i) {
    final next = [...widget.urls]..removeAt(i);
    widget.onChanged(next);
  }

  void _makeCover(int i) {
    if (i == 0) return;
    final next = [...widget.urls];
    final img = next.removeAt(i);
    next.insert(0, img);
    widget.onChanged(next);
  }

  String _mimeFor(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'avif':
        return 'image/avif';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = widget.urls.length < widget.maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thư viện ảnh', style: theme.textTheme.labelLarge),
        const SizedBox(height: BananSpacing.xs),
        Text(
          'Đã có ${widget.urls.length}/${widget.maxImages} ảnh. Ảnh đầu tiên '
          'làm ảnh bìa. Chạm vào một ảnh để chọn làm ảnh bìa.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          'Khuyến nghị: 1200×900px  ·  ≤ 8 MB/ảnh '
          '(server chấp nhận tối đa 20 MB)  ·  JPG / PNG / WebP / AVIF',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: BananSpacing.sm),
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            for (var i = 0; i < widget.urls.length; i++)
              _Tile(
                url: widget.urls[i],
                isCover: i == 0,
                onMakeCover: () => _makeCover(i),
                onRemove: () => _removeAt(i),
              ),
            if (canAdd)
              InkWell(
                onTap: _uploading ? null : _pick,
                borderRadius: BananRadii.rmd,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rmd,
                    color: BananColors.surfaceDim,
                    border: Border.all(color: BananColors.cocoaSoft),
                  ),
                  alignment: Alignment.center,
                  child: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: BananColors.cocoaSoft,),
                            SizedBox(height: 4),
                            Text('Thêm', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: BananSpacing.xs),
          Text(
            _error!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.url,
    required this.isCover,
    required this.onMakeCover,
    required this.onRemove,
  });

  final String url;
  final bool isCover;
  final VoidCallback onMakeCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onMakeCover,
              borderRadius: BananRadii.rmd,
              child: ClipRRect(
                borderRadius: BananRadii.rmd,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: BananColors.surfaceDim,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: BananColors.cocoaSoft,),
                  ),
                ),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2,),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Ảnh bìa',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 16,),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
