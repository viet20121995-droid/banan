import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Combined sign-in / sign-up screen with the two-panel "sliding overlay"
/// design. One card holds BOTH forms side-by-side on wide screens; a tinted
/// overlay panel slides left↔right to reveal sign-in or sign-up and carries the
/// toggle button. On narrow (mobile) screens it collapses to a single form with
/// a segmented toggle at the top.
///
/// Same fields + logic as the old LoginScreen/RegisterScreen — it drives the
/// shared [authControllerProvider]; the router redirects to home (honouring
/// `?next=`) once the session updates. Staff (merchant/kitchen) apps keep the
/// original shared screens.
class AuthSliderScreen extends ConsumerStatefulWidget {
  const AuthSliderScreen({this.initialSignUp = false, super.key});

  /// Whether the "Create account" side is active on first show
  /// (/register → true, /login → false).
  final bool initialSignUp;

  @override
  ConsumerState<AuthSliderScreen> createState() => _AuthSliderScreenState();
}

class _AuthSliderScreenState extends ConsumerState<AuthSliderScreen> {
  late bool _signUp = widget.initialSignUp;

  // Sign-in form.
  final _loginKey = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  final _loginPw = TextEditingController();
  bool _loginObscure = true;

  // Sign-up form.
  final _regKey = GlobalKey<FormState>();
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPhone = TextEditingController();
  final _regPw = TextEditingController();
  bool _regObscure = true;
  DateTime? _birthday;

  @override
  void dispose() {
    _loginId.dispose();
    _loginPw.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPhone.dispose();
    _regPw.dispose();
    super.dispose();
  }

  void _switchTo(bool signUp) {
    if (_signUp == signUp) return;
    // Drop any error from the other form so it doesn't bleed across.
    ref.read(authControllerProvider.notifier).clearFailure();
    setState(() => _signUp = signUp);
  }

  Future<void> _submitLogin() async {
    if (!_loginKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          emailOrPhone: _loginId.text,
          password: _loginPw.text,
        );
    // On success the auth session stream fires and the router redirects.
  }

  Future<void> _submitRegister() async {
    if (!_regKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).register(
          email: _regEmail.text,
          password: _regPw.text,
          fullName: _regName.text,
          phone: _regPhone.text.isEmpty ? null : _regPhone.text,
          birthday: _birthday,
        );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Ngày sinh của bạn',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: LayoutBuilder(
                  builder: (context, _) {
                    final wide = MediaQuery.sizeOf(context).width >= 820;
                    return wide ? _wideCard(theme) : _narrowCard(theme);
                  },
                ),
              ),
            ),
            // Guests reach /login while browsing (a protected-route redirect or
            // the menu's sign-in button) — give them a way back to the shop
            // instead of a dead-end. Pop to the previous page, or fall back home.
            Positioned(
              top: BananSpacing.xs,
              left: BananSpacing.xs,
              child: TextButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Quay lại cửa hàng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide: two panes + sliding overlay ──────────────────────────────────────
  Widget _wideCard(ThemeData theme) {
    const w = 860.0;
    const h = 560.0;
    const half = w / 2;
    return _CardShell(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // Sign-in form (left half).
            Positioned(
              left: 0,
              top: 0,
              width: half,
              height: h,
              child: _pane(child: _signInForm(theme)),
            ),
            // Sign-up form (right half).
            Positioned(
              left: half,
              top: 0,
              width: half,
              height: h,
              child: _pane(child: _signUpForm(theme)),
            ),
            // Sliding overlay — covers the left half when signing up (so the
            // sign-up form on the right shows), and the right half when signing
            // in. Carries the welcome message + the toggle button.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              left: _signUp ? 0 : half,
              top: 0,
              width: half,
              height: h,
              child: _OverlayPane(
                signUpActive: _signUp,
                onToggle: () => _switchTo(!_signUp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Narrow: single form + segmented toggle ──────────────────────────────────
  Widget _narrowCard(ThemeData theme) {
    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SegmentedToggle(
                signUpActive: _signUp,
                onChanged: _switchTo,
              ),
              const SizedBox(height: BananSpacing.xl),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _signUp
                    ? KeyedSubtree(
                        key: const ValueKey('signup'),
                        child: _signUpForm(theme),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('signin'),
                        child: _signInForm(theme),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Forms ───────────────────────────────────────────────────────────────────
  Widget _signInForm(ThemeData theme) {
    final state = ref.watch(authControllerProvider);
    final s = ref.watch(stringsProvider);
    return _FormScaffold(
      formKey: _loginKey,
      title: 'Đăng nhập',
      children: [
        _SoftField(
          controller: _loginId,
          label: s.emailOrPhone,
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
        ),
        const SizedBox(height: BananSpacing.md),
        _SoftField(
          controller: _loginPw,
          label: s.password,
          icon: Icons.lock_outline,
          obscure: _loginObscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submitLogin(),
          onToggleObscure: () =>
              setState(() => _loginObscure = !_loginObscure),
          validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: state.submitting
                ? null
                : () => context.push('/forgot-password'),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        if (state.failure != null) _errorBox(theme, state.failure!),
        const SizedBox(height: BananSpacing.lg),
        PrimaryButton(
          label: s.signIn,
          loading: state.submitting,
          expand: true,
          onPressed: _submitLogin,
        ),
      ],
    );
  }

  Widget _signUpForm(ThemeData theme) {
    final state = ref.watch(authControllerProvider);
    final s = ref.watch(stringsProvider);
    return _FormScaffold(
      formKey: _regKey,
      title: 'Tạo tài khoản',
      children: [
        _SoftField(
          controller: _regName,
          label: s.fullName,
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
        ),
        const SizedBox(height: BananSpacing.md),
        _SoftField(
          controller: _regEmail,
          label: s.email,
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Bắt buộc';
            if (!v.contains('@')) return 'Email không hợp lệ';
            return null;
          },
        ),
        const SizedBox(height: BananSpacing.md),
        _SoftField(
          controller: _regPhone,
          label: '${s.phone} (tuỳ chọn)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: BananSpacing.md),
        _BirthdayField(value: _birthday, onTap: _pickBirthday),
        const SizedBox(height: BananSpacing.md),
        _SoftField(
          controller: _regPw,
          label: s.password,
          icon: Icons.lock_outline,
          obscure: _regObscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitRegister(),
          onToggleObscure: () => setState(() => _regObscure = !_regObscure),
          validator: (v) =>
              (v == null || v.length < 8) ? 'Tối thiểu 8 ký tự' : null,
        ),
        if (state.failure != null) _errorBox(theme, state.failure!),
        const SizedBox(height: BananSpacing.lg),
        PrimaryButton(
          label: s.createAccount,
          loading: state.submitting,
          expand: true,
          onPressed: _submitRegister,
        ),
      ],
    );
  }

  Widget _errorBox(ThemeData theme, AppFailure failure) {
    return Padding(
      padding: const EdgeInsets.only(top: BananSpacing.md),
      child: Container(
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
                authFailureMessage(failure),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A pane wrapping a form with centred, scrollable content.
  Widget _pane({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.xxl,
        vertical: BananSpacing.xl,
      ),
      child: Center(child: SingleChildScrollView(child: child)),
    );
  }
}

/// The rounded, soft-shadowed card that frames the whole auth UI.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rxl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BananRadii.rxl, child: child),
    );
  }
}

/// Title + fields + (the children include the action button). Used by both
/// panes and the narrow layout.
class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.formKey,
    required this.title,
    required this.children,
  });
  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BananSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

/// The sliding panel: welcome copy + the toggle (ghost) button. Tinted so the
/// slide is clearly visible over the cream forms.
class _OverlayPane extends StatelessWidget {
  const _OverlayPane({required this.signUpActive, required this.onToggle});
  final bool signUpActive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // When sign-up is active the overlay invites you to sign in, and vice-versa.
    final title = signUpActive ? 'Chào mừng trở lại!' : 'Xin chào!';
    final body = signUpActive
        ? 'Đã có tài khoản? Đăng nhập để tiếp tục đặt bánh.'
        : 'Chưa có tài khoản? Đăng ký để tích điểm và đặt nhanh hơn.';
    final cta = signUpActive ? 'ĐĂNG NHẬP' : 'ĐĂNG KÝ';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.12),
              theme.colorScheme.primary,
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.xxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(signUpActive),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: BananSpacing.md),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BananSpacing.xl),
              OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onPrimary,
                  side: BorderSide(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BananSpacing.xxl,
                    vertical: BananSpacing.md,
                  ),
                ),
                child: Text(
                  cta,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top tab toggle for the narrow layout.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.signUpActive, required this.onChanged});
  final bool signUpActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tab(String label, bool isSignUp) {
      final active = signUpActive == isSignUp;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isSignUp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
            decoration: BoxDecoration(
              color: active ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BananRadii.rPill,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: active
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BananRadii.rPill,
      ),
      child: Row(
        children: [tab('Đăng nhập', false), tab('Đăng ký', true)],
      ),
    );
  }
}

/// A soft, rounded text field used across the forms.
class _SoftField extends StatelessWidget {
  const _SoftField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
      ),
    );
  }
}

/// Optional birthday picker field (read-only, opens a date picker).
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
          labelText: 'Ngày sinh (tuỳ chọn)',
          helperText: 'Tặng bạn ưu đãi mỗi dịp sinh nhật.',
          prefixIcon: Icon(Icons.cake_outlined, size: 20),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? 'Chạm để chọn…' : fmt.format(value!)),
      ),
    );
  }
}
