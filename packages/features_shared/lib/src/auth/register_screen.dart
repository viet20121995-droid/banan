import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_failure_message.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    this.onRegistered,
    this.onBackToLogin,
    super.key,
  });

  final VoidCallback? onRegistered;
  final VoidCallback? onBackToLogin;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.length < 8) return 'Min 8 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          phone: _phone.text.isEmpty ? null : _phone.text,
        );
    if (ok && mounted) widget.onRegistered?.call();
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
                Text('Create your Banan account',
                    style: theme.textTheme.displaySmall),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  'Earn points on every order. Free to join.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: BananSpacing.xxl),
                _Field(label: 'Full name', controller: _name, icon: Icons.person_outline),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: 'Email',
                  controller: _email,
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: 'Phone (optional)',
                  controller: _phone,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  required: false,
                ),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: 'Password',
                  controller: _password,
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: _validatePassword,
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
                    child: Text(authFailureMessage(state.failure!)),
                  ),
                ],
                const SizedBox(height: BananSpacing.xl),
                PrimaryButton(
                  label: 'Create account',
                  loading: state.submitting,
                  expand: true,
                  onPressed: _submit,
                ),
                const SizedBox(height: BananSpacing.md),
                TextButton(
                  onPressed: state.submitting ? null : widget.onBackToLogin,
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.required = true,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator ??
          (v) => required && (v == null || v.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
