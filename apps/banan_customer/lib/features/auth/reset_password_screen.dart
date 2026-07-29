import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public "reset password" screen reached from the emailed link. The reset
/// [token] arrives as a query parameter. The customer sets a new password
/// (min 8 chars, confirmed twice); on success we let them head to login.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ref.read(authRepositoryProvider).resetPassword(
          token: widget.token,
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      success: (_) => setState(() => _done = true),
      failure: (f) => setState(
        () => _error = authFailureMessage(f, ref.read(stringsProvider)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(stringsProvider).resetTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: _buildBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final s = ref.watch(stringsProvider);
    // No token → the link is malformed or was opened directly.
    if (widget.token.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.link_off_outlined, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: BananSpacing.lg),
          Text(
            s.resetLinkInvalid,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: BananSpacing.xl),
          FilledButton(
            onPressed: () => context.go('/forgot-password'),
            child: Text(s.requestNewLink),
          ),
        ],
      );
    }

    if (_done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 56,
            color: BananColors.success,
          ),
          const SizedBox(height: BananSpacing.lg),
          Text(
            s.resetDone,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: BananSpacing.xl),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: Text(s.signIn),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.resetIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BananSpacing.xl),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(BananSpacing.md),
              margin: const EdgeInsets.only(bottom: BananSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BananRadii.rmd,
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              ),
              child: Text(_error!),
            ),
          TextFormField(
            controller: _newPassword,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: s.newPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) => (v == null || v.length < 8) ? s.pwMin8 : null,
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: s.confirmNewPassword,
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) => (v != _newPassword.text) ? s.pwMismatch : null,
          ),
          const SizedBox(height: BananSpacing.xl),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset_outlined),
            label: Text(s.resetTitle),
          ),
        ],
      ),
    );
  }
}
