import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Self-service "Đổi mật khẩu" screen for kitchen staff. Verifies the current
/// password and applies a new one via `AuthRepository.changePassword`.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  String? _currentError;
  String? _nextError;
  String? _confirmError;
  String? _failure;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;

    String? currentError;
    String? nextError;
    String? confirmError;

    if (current.isEmpty) {
      currentError = 'Vui lòng nhập mật khẩu hiện tại';
    }
    if (next.length < 8) {
      nextError = 'Mật khẩu mới phải có ít nhất 8 ký tự';
    } else if (next == current) {
      nextError = 'Mật khẩu mới phải khác mật khẩu hiện tại';
    }
    if (confirm != next) {
      confirmError = 'Mật khẩu xác nhận không khớp';
    }

    setState(() {
      _currentError = currentError;
      _nextError = nextError;
      _confirmError = confirmError;
    });

    return currentError == null && nextError == null && confirmError == null;
  }

  Future<void> _submit() async {
    setState(() => _failure = null);
    if (!_validate()) return;

    setState(() => _submitting = true);
    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      failure: (f) => setState(() => _failure = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Đổi mật khẩu',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  'Nhập mật khẩu hiện tại và mật khẩu mới (tối thiểu 8 ký tự).',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: BananSpacing.xl),
                AppTextField(
                  controller: _current,
                  label: 'Mật khẩu hiện tại',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureCurrent,
                  enabled: !_submitting,
                  errorText: _currentError,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  suffix: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                const SizedBox(height: BananSpacing.md),
                AppTextField(
                  controller: _next,
                  label: 'Mật khẩu mới',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: _obscureNext,
                  enabled: !_submitting,
                  errorText: _nextError,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNext
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNext = !_obscureNext),
                  ),
                ),
                const SizedBox(height: BananSpacing.md),
                AppTextField(
                  controller: _confirm,
                  label: 'Xác nhận mật khẩu mới',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: _obscureConfirm,
                  enabled: !_submitting,
                  errorText: _confirmError,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                if (_failure != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(BananSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BananRadii.rmd,
                      color: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.4),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: BananSpacing.sm),
                        Expanded(
                          child: Text(
                            _failure!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: BananSpacing.xl),
                PrimaryButton(
                  label: 'Đổi mật khẩu',
                  icon: Icons.check,
                  loading: _submitting,
                  expand: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
