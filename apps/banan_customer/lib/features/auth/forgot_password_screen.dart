import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public "forgot password" screen. The customer enters their email and we
/// trigger a reset-link email. We intentionally show a neutral confirmation
/// regardless of whether the email exists, so the form never reveals which
/// addresses are registered.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res =
        await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      // Neutral confirmation either way — do not reveal account existence.
      success: (_) => setState(() => _sent = true),
      failure: (f) => setState(
        () => _error = authFailureMessage(f, ref.read(stringsProvider)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.forgotTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 56,
                        color: BananColors.primary,
                      ),
                      const SizedBox(height: BananSpacing.lg),
                      Text(
                        s.forgotSent,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: BananSpacing.xl),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: Text(s.backToLogin),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.forgotIntro,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: BananSpacing.xl),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(BananSpacing.md),
                            margin: const EdgeInsets.only(
                              bottom: BananSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BananRadii.rmd,
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.4),
                            ),
                            child: Text(_error!),
                          ),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) {
                              return s.pleaseEnterEmail;
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return s.invalidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: BananSpacing.xl),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(s.sendResetLink),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
