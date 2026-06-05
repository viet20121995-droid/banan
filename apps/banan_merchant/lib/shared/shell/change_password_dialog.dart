import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the "Đổi mật khẩu" dialog for the signed-in user. Verifies the
/// current password and applies a new one via [authRepositoryProvider].
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu')),
        );
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                margin: const EdgeInsets.only(bottom: BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color:
                      theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                ),
                child: Text(_error!),
              ),
            TextFormField(
              controller: _current,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (tối thiểu 8 ký tự)',
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Tối thiểu 8 ký tự' : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
              validator: (v) =>
                  (v != _next.text) ? 'Mật khẩu nhập lại không khớp' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}
