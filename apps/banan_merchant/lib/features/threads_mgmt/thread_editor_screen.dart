import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart' as domain;
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/cover_image_picker.dart';
import 'threads_list_screen.dart';

final _editorThreadProvider = FutureProvider.autoDispose
    .family<domain.Thread, String>((ref, id) async {
  final repo = ref.watch(threadsRepositoryProvider);
  final res = await repo.get(id);
  return res.when(
    success: (t) => t,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class ThreadEditorScreen extends ConsumerStatefulWidget {
  const ThreadEditorScreen({this.threadId, super.key});

  final String? threadId;
  bool get isEditing => threadId != null;

  @override
  ConsumerState<ThreadEditorScreen> createState() =>
      _ThreadEditorScreenState();
}

class _ThreadEditorScreenState extends ConsumerState<ThreadEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _coverUrl;
  bool _publish = false;
  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _hydrateFrom(domain.Thread t) {
    if (_initialized) return;
    _initialized = true;
    _title.text = t.title;
    _body.text = t.body;
    _coverUrl = t.imageUrl;
    _publish = t.isPublished;
    setState(() {});
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _publish = publish;
    });
    final draft = domain.ThreadDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
      imageUrl: _coverUrl,
      publish: publish,
    );
    final repo = ref.read(threadsRepositoryProvider);
    final res = widget.isEditing
        ? await repo.update(widget.threadId!, draft)
        : await repo.create(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(threadsControllerProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorThreadProvider(widget.threadId!));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
        data: (t) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(t));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit thread' : 'New thread'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(publish: false),
            child: const Text('Save draft'),
          ),
          const SizedBox(width: BananSpacing.sm),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(publish: true),
            icon: _saving && _publish
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(widget.isEditing && _publish ? 'Update' : 'Publish'),
          ),
          const SizedBox(width: BananSpacing.md),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.xl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(BananSpacing.md),
                        margin:
                            const EdgeInsets.only(bottom: BananSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BananRadii.rmd,
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.4),
                        ),
                        child: Text(_error!),
                      ),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        helperText: 'Up to 140 characters',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    CoverImagePicker(
                      url: _coverUrl,
                      onChanged: (url) => setState(() => _coverUrl = url),
                      helperText:
                          'Shown on the customer home thread strip.',
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    TextFormField(
                      controller: _body,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                        helperText:
                            'Markdown not supported yet — plain text only.',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
