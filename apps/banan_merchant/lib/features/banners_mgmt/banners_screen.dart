import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/cover_image_picker.dart';
import '../../shared/shell/merchant_shell.dart';

final _bannersProvider =
    FutureProvider.autoDispose<List<HomeBanner>>((ref) async {
  final res = await ref.watch(bannersRepositoryProvider).list();
  return res.when(
    success: (l) => l,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

class BannersScreen extends ConsumerWidget {
  const BannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_bannersProvider);
    return MerchantShell(
      title: 'Banner trang chủ',
      onRefresh: () async => ref.invalidate(_bannersProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Thêm banner'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_bannersProvider),
        ),
        data: (banners) {
          if (banners.isEmpty) {
            return const EmptyState(
              title: 'Chưa có banner',
              message: 'Thêm ảnh banner hiển thị ở trang chủ khách hàng.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_bannersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: banners.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.md),
              itemBuilder: (_, i) => _BannerCard(banner: banners[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _BannerEditorSheet(),
    );
    if (saved ?? false) ref.invalidate(_bannersProvider);
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.banner});
  final HomeBanner banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(bannersRepositoryProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 6,
            child: Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: BananColors.surfaceDim,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BananSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title?.isNotEmpty ?? false
                            ? banner.title!
                            : '(không tiêu đề)',
                        style: theme.textTheme.titleSmall,
                      ),
                      if (banner.chainWide)
                        Text('Toàn chuỗi',
                            style: theme.textTheme.labelSmall,),
                    ],
                  ),
                ),
                if (banner.editable) ...[
                  Text(banner.isActive ? 'Hiện' : 'Ẩn',
                      style: theme.textTheme.labelMedium,),
                  Switch(
                    value: banner.isActive,
                    onChanged: (v) async {
                      final r =
                          await repo.update(banner.id, isActive: v);
                      r.when(
                        success: (_) =>
                            ref.invalidate(_bannersProvider),
                        failure: (f) =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(authFailureMessage(f)),),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xoá',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xoá banner?'),
                          content: const Text(
                              'Hành động này không thể hoàn tác.',),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: const Text('Huỷ'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              child: const Text('Xoá'),
                            ),
                          ],
                        ),
                      );
                      if (ok ?? false) {
                        await repo.delete(banner.id);
                        ref.invalidate(_bannersProvider);
                      }
                    },
                  ),
                ] else
                  Text('Chỉ xem', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerEditorSheet extends ConsumerStatefulWidget {
  const _BannerEditorSheet();

  @override
  ConsumerState<_BannerEditorSheet> createState() =>
      _BannerEditorSheetState();
}

class _BannerEditorSheetState extends ConsumerState<_BannerEditorSheet> {
  final _title = TextEditingController();
  final _ctaUrl = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');
  String? _imageUrl;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _ctaUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      setState(() => _error = 'Hãy tải ảnh banner lên.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref.read(bannersRepositoryProvider).create(
          BannerDraft(
            imageUrl: _imageUrl!,
            title: _title.text.trim().isEmpty ? null : _title.text.trim(),
            ctaUrl:
                _ctaUrl.text.trim().isEmpty ? null : _ctaUrl.text.trim(),
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          BananSpacing.lg, 0, BananSpacing.lg, bottom + BananSpacing.lg,),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Thêm banner', style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(BananSpacing.md),
              margin: const EdgeInsets.only(bottom: BananSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BananRadii.rmd,
                color: theme.colorScheme.errorContainer
                    .withValues(alpha: 0.4),
              ),
              child: Text(_error!),
            ),
          CoverImagePicker(
            url: _imageUrl,
            label: 'Ảnh banner',
            helperText: 'Hiển thị ở đầu trang chủ khách hàng.',
            recommendedSize: '1600×600px (tỉ lệ 16:6, ngang)',
            onChanged: (url) => setState(() => _imageUrl = url),
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề (tuỳ chọn)',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _ctaUrl,
            decoration: const InputDecoration(
              labelText: 'Liên kết khi bấm (tuỳ chọn)',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _sortOrder,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Thứ tự hiển thị (nhỏ hiện trước)',
            ),
          ),
          const SizedBox(height: BananSpacing.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Tạo banner'),
          ),
        ],
      ),
    );
  }
}
