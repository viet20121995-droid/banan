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
    this.label = 'Cover image',
    this.helperText = 'Optional — shown on the customer site.',
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

  @override
  ConsumerState<CoverImagePicker> createState() => _CoverImagePickerState();
}

class _CoverImagePickerState extends ConsumerState<CoverImagePicker> {
  bool _uploading = false;
  String? _error;

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
        () => _error = 'Upload failed: ${authFailureMessage(f)}',
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
                        label: Text(hasImage ? 'Replace' : 'Upload from device'),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: BananSpacing.sm),
                        TextButton.icon(
                          onPressed:
                              _uploading ? null : () => widget.onChanged(null),
                          icon: const Icon(Icons.close),
                          label: const Text('Remove'),
                        ),
                      ],
                    ],
                  ),
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
