import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_failure_message.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    required this.title,
    required this.subtitle,
    this.showRegisterLink = false,
    this.onRegisterTapped,
    this.onLoggedIn,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showRegisterLink;
  final VoidCallback? onRegisterTapped;
  final VoidCallback? onLoggedIn;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(
          emailOrPhone: _email.text,
          password: _password.text,
        );
    if (ok && mounted) widget.onLoggedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: theme.textTheme.displaySmall),
                const SizedBox(height: BananSpacing.sm),
                Text(widget.subtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: BananSpacing.xxl),
                AppTextField(
                  controller: _email,
                  label: 'Email or phone',
                  prefixIcon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: BananSpacing.md),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (state.failure != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(BananSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BananRadii.rmd,
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                      border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: BananSpacing.sm),
                        Expanded(
                          child: Text(
                            authFailureMessage(state.failure!),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: BananSpacing.xl),
                PrimaryButton(
                  label: 'Sign in',
                  loading: state.submitting,
                  expand: true,
                  onPressed: _submit,
                ),
                if (widget.showRegisterLink) ...[
                  const SizedBox(height: BananSpacing.md),
                  TextButton(
                    onPressed: state.submitting ? null : widget.onRegisterTapped,
                    child: const Text("Don't have an account? Create one"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
