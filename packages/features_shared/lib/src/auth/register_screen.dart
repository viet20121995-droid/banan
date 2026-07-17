import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../i18n/app_strings.dart';
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
  DateTime? _birthday;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Your birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
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
          birthday: _birthday,
        );
    if (ok && mounted) widget.onRegistered?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);

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
                Text(s.registerTitle,
                    style: theme.textTheme.displaySmall,),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  s.registerSubtitle,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: BananSpacing.xxl),
                _Field(label: s.fullName, controller: _name, icon: Icons.person_outline),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: s.email,
                  controller: _email,
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: s.phone,
                  controller: _phone,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: BananSpacing.md),
                _BirthdayField(
                  value: _birthday,
                  onTap: _pickBirthday,
                ),
                const SizedBox(height: BananSpacing.md),
                _Field(
                  label: s.password,
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
                  label: s.createAccount,
                  loading: state.submitting,
                  expand: true,
                  onPressed: _submit,
                ),
                const SizedBox(height: BananSpacing.md),
                TextButton(
                  onPressed: state.submitting ? null : widget.onBackToLogin,
                  child: Text(s.backToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only field that opens a date picker on tap. Birthday is optional —
/// the helper text nudges the user without making it a hard requirement.
class _BirthdayField extends StatelessWidget {
  const _BirthdayField({required this.value, required this.onTap});
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rmd,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Birthday (optional)',
          helperText: "We'll send you a treat each year.",
          prefixIcon: Icon(Icons.cake_outlined, size: 20),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? 'Tap to choose…' : fmt.format(value!),
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
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      // Every caller either passes its own validator or wants "not empty" —
      // nothing ever opted out, so there is no `required` flag to honour.
      validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
