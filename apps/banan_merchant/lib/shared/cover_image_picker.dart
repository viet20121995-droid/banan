import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reusable cover-image picker used by the collection and thread editors.
/// Lets the merchant upload an image from their device — the file is
/// posted to `/uploads`, and the returned public URL becomes the value.
///
/// Stateless from the caller's perspective: parent owns the URL string and
/// rebuilds with a new [url] after [onChanged] fires.
class CoverImagePicker extends ConsumerStatefulWidget {
  const CoverImagePicker({
    required this.url,
    required this.onChanged,
    this.label = 'Ảnh bìa',
    this.helperText = 'Tuỳ chọn, hiển thị trên trang khách hàng.',
    this.recommendedSize = '1200×800px (tỉ lệ 3:2)',
    this.recommendedFileSizeMb = 8,
    this.hardMaxFileSizeMb = 20,
    super.key,
  });

  /// Currently-saved URL, or null when none. Display-only — parent state is
  /// authoritative.
  final String? url;

  /// Called with the new URL after a successful upload, or `null` when the
  /// merchant clears the image.
  final ValueChanged<String?> onChanged;

  final String label;
  final String helperText;

  /// Free-form text shown in the guidance line — caller picks the right
  /// value for the context (banner: 1600×600, popup: 1200×900, etc.).
  final String recommendedSize;

  /// "Comfortable" file-size ceiling — above this we show a non-blocking
  /// warning ("vượt mức khuyến nghị") so the merchant knows the file may
  /// slow down the customer site. Uploads still proceed.
  final int recommendedFileSizeMb;

  /// Hard server limit (matches backend Multer config). Files above this
  /// are rejected by the server with `LIMIT_FILE_SIZE`.
  final int hardMaxFileSizeMb;

  @override
  ConsumerState<CoverImagePicker> createState() => _CoverImagePickerState();
}

class _CoverImagePickerState extends ConsumerState<CoverImagePicker> {
  bool _uploading = false;
  String? _error;
  // Last picked file's reported size in bytes — surfaced as a hint so the
  // merchant can spot oversized assets before they try a save that will
  // be slow on a poor connection.
  int? _lastFileSize;
  String? _lastFilename;

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
      _lastFileSize = file.size;
      _lastFilename = file.name;
    });
    final repo = ref.read(catalogRepositoryProvider);
    final res = await repo.uploadImage(
      bytes: file.bytes!,
      filename: file.name,
      mimeType: _mimeFor(file.extension),
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    res.when(
      success: (uploaded) => widget.onChanged(uploaded.url),
      failure: (f) => setState(
        () => _error = 'Tải ảnh thất bại: ${authFailureMessage(f)}',
      ),
    );
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
    final hasImage = widget.url != null && widget.url!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: BananSpacing.xs),
        Text(widget.helperText, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        // Standardized image guidance — same shape across every picker so
        // merchants learn the format once. Two-tier sizing: a soft
        // recommendation (warning shown above) and a hard server limit.
        Text(
          'Khuyến nghị: ${widget.recommendedSize}  ·  '
          '≤ ${widget.recommendedFileSizeMb} MB '
          '(server chấp nhận tối đa ${widget.hardMaxFileSizeMb} MB)  ·  '
          'JPG / PNG / WebP / AVIF',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: BananSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BananRadii.rmd,
              child: SizedBox(
                width: 120,
                height: 120,
                child: hasImage
                    ? Image.network(
                        widget.url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: BananColors.surfaceDim,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: BananColors.cocoaSoft,
                          ),
                        ),
                      )
                    : Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: BananColors.cocoaSoft,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _uploading ? null : _pick,
                        icon: _uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_outlined),
                        label: Text(hasImage ? 'Thay ảnh' : 'Tải lên từ máy'),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: BananSpacing.sm),
                        TextButton.icon(
                          onPressed:
                              _uploading ? null : () => widget.onChanged(null),
                          icon: const Icon(Icons.close),
                          label: const Text('Xoá'),
                        ),
                      ],
                    ],
                  ),
                  if (_lastFileSize != null && _lastFilename != null) ...[
                    const SizedBox(height: BananSpacing.xs),
                    _FileMeta(
                      filename: _lastFilename!,
                      sizeBytes: _lastFileSize!,
                      recommendedMb: widget.recommendedFileSizeMb,
                      hardMaxMb: widget.hardMaxFileSizeMb,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Inline filename + size summary shown after a file is picked. Three
/// states by file size relative to the two-tier limits:
///   - ≤ recommended  → quiet green check
///   - > recommended but ≤ hard max → amber warning (still uploads OK)
///   - > hard max → red error (server will reject)
class _FileMeta extends StatelessWidget {
  const _FileMeta({
    required this.filename,
    required this.sizeBytes,
    required this.recommendedMb,
    required this.hardMaxMb,
  });

  final String filename;
  final int sizeBytes;
  final int recommendedMb;
  final int hardMaxMb;

  String _human(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overHard = sizeBytes > hardMaxMb * 1024 * 1024;
    final overSoft = sizeBytes > recommendedMb * 1024 * 1024;

    final (icon, color, note) = overHard
        ? (
            Icons.error_outline_rounded,
            theme.colorScheme.error,
            '  · vượt giới hạn server ($hardMaxMb MB), sẽ bị từ chối',
          )
        : overSoft
            ? (
                Icons.warning_amber_rounded,
                Colors.orange.shade700,
                '  · vượt mức khuyến nghị ($recommendedMb MB), vẫn tải lên được',
              )
            : (
                Icons.check_circle_outline,
                theme.colorScheme.outline,
                '',
              );

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$filename  ·  ${_human(sizeBytes)}$note',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight:
                  (overHard || overSoft) ? FontWeight.w600 : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
