import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/locale_store.dart';

/// Lets a signed-in customer edit their personal details (name, phone,
/// birthday, avatar). Email is shown read-only — it's the login identity.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _avatar = TextEditingController();
  DateTime? _birthday;
  Gender? _gender;
  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  // Notification preferences — hydrated from the current user, toggled
  // independently of the main "Lưu thay đổi" save via updateProfile.
  bool _marketingOptIn = true;
  bool _orderUpdatesOptIn = true;
  bool _savingPrefs = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _avatar.dispose();
    super.dispose();
  }

  void _hydrate(User u) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = u.fullName;
    _phone.text = u.phone ?? '';
    _avatar.text = u.avatarUrl ?? '';
    _birthday = u.birthday;
    _gender = u.gender;
    _marketingOptIn = u.marketingOptIn;
    _orderUpdatesOptIn = u.orderUpdatesOptIn;
  }

  /// Toggle one of the two notification opt-ins. Optimistically flips the
  /// switch, then persists via `updateProfile`; on failure we revert and
  /// surface a snackbar so the UI never lies about the saved state.
  Future<void> _togglePref({
    bool? marketing,
    bool? orderUpdates,
  }) async {
    if (_savingPrefs) return;
    setState(() {
      _savingPrefs = true;
      if (marketing != null) _marketingOptIn = marketing;
      if (orderUpdates != null) _orderUpdatesOptIn = orderUpdates;
    });
    final res = await ref.read(authRepositoryProvider).updateProfile(
          marketingOptIn: marketing,
          orderUpdatesOptIn: orderUpdates,
        );
    if (!mounted) return;
    setState(() => _savingPrefs = false);
    res.when(
      success: (_) {},
      failure: (f) {
        // Revert the optimistic flip on failure.
        setState(() {
          if (marketing != null) _marketingOptIn = !marketing;
          if (orderUpdates != null) _orderUpdatesOptIn = !orderUpdates;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        );
      },
    );
  }

  Future<void> _openChangeEmail() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ChangeEmailSheet(),
    );
    if ((changed ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi liên kết xác nhận tới email mới. '
            'Vui lòng kiểm tra hộp thư.',
          ),
        ),
      );
    }
  }

  Future<void> _openDeleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if ((deleted ?? false) && mounted) {
      // Clear the local session via the shared logout flow, then bounce to
      // the login screen. The router's redirect would also catch this, but
      // navigating explicitly avoids a flash of the (now empty) profile.
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save(User original) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final avatar = _avatar.text.trim();
    final origBirthday = original.birthday == null
        ? null
        : DateTime(
            original.birthday!.year,
            original.birthday!.month,
            original.birthday!.day,
          );
    final newBirthday = _birthday == null
        ? null
        : DateTime(_birthday!.year, _birthday!.month, _birthday!.day);

    final res =
        await ref.read(authRepositoryProvider).updateProfile(
              fullName: name == original.fullName ? null : name,
              phone: phone == (original.phone ?? '') ? null : phone,
              avatarUrl: avatar == (original.avatarUrl ?? '') ? null : avatar,
              birthday: newBirthday == origBirthday ? null : newBirthday,
              clearBirthday: origBirthday != null && newBirthday == null,
              // Only send gender when the user picked/changed it. The backend
              // has no "clear" path, so an unchanged (incl. unset) value is
              // simply omitted.
              gender: _gender == original.gender ? null : _gender,
            );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(stringsProvider).profileUpdated),
          ),
        );
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final loc = ref.watch(localeProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.profileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final user = session.user;
    _hydrate(user);
    final initials = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim().split(RegExp(r'\s+')).take(2).map((w) {
            return w[0].toUpperCase();
          }).join();

    return Scaffold(
      appBar: AppBar(title: Text(s.profileTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: BananColors.gold,
                        backgroundImage: (user.avatarUrl != null &&
                                user.avatarUrl!.isNotEmpty)
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: (user.avatarUrl == null ||
                                user.avatarUrl!.isEmpty)
                            ? Text(
                                initials,
                                style: theme.textTheme.headlineMedium
                                    ?.copyWith(color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(BananSpacing.md),
                        margin: const EdgeInsets.only(
                            bottom: BananSpacing.lg,),
                        decoration: BoxDecoration(
                          borderRadius: BananRadii.rmd,
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.4),
                        ),
                        child: Text(_error!),
                      ),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: s.fullName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s.pleaseEnterName
                          : null,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    TextFormField(
                      initialValue: user.email,
                      readOnly: true,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: s.emailSignIn,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: BananSpacing.md),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: s.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: BananSpacing.md),
                    InkWell(
                      onTap: _pickBirthday,
                      borderRadius: BananRadii.rmd,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: s.birthday,
                          prefixIcon: const Icon(Icons.cake_outlined),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _birthday == null
                                    ? s.notSet
                                    : DateFormat.yMMMMd()
                                        .format(_birthday!),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            if (_birthday != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _birthday = null),
                              ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18,),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: BananSpacing.md),
                    // Gender — optional. Tapping the already-selected chip
                    // clears it back to "not set".
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Giới tính',
                        prefixIcon: Icon(Icons.wc_outlined),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: BananSpacing.sm,
                          children: [
                            for (final g in Gender.values)
                              ChoiceChip(
                                label: Text(g.label),
                                selected: _gender == g,
                                onSelected: (sel) => setState(
                                  () => _gender = sel ? g : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: BananSpacing.md),
                    TextFormField(
                      controller: _avatar,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: s.avatarUrlOptional,
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: BananSpacing.xl),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(user),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(s.saveChanges),
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: BananSpacing.sm,),
                      child: Row(
                        children: [
                          const Icon(Icons.translate),
                          const SizedBox(width: BananSpacing.md),
                          Text(s.language),
                          const Spacer(),
                          SegmentedButton<AppLocale>(
                            segments: const [
                              ButtonSegment(
                                value: AppLocale.vi,
                                label: Text('VI'),
                              ),
                              ButtonSegment(
                                value: AppLocale.en,
                                label: Text('EN'),
                              ),
                            ],
                            selected: {loc},
                            onSelectionChanged: (sel) {
                              final next = sel.first;
                              ref.read(localeProvider.notifier).state = next;
                              // Persist so the choice survives a page
                              // reload — main.dart restores it on boot.
                              saveLocale(next);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(s.savedAddresses),
                      subtitle: Text(s.savedAddressesSub),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/addresses'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite_outline),
                      title: const Text('Yêu thích'),
                      subtitle: const Text(
                        'Bánh & sản phẩm bạn đã lưu lại để xem sau.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/wishlist'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: const Text('Ví voucher'),
                      subtitle: const Text(
                        'Mã giảm giá khả dụng, đã dùng và hết hạn.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/vouchers'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Đổi mật khẩu'),
                      subtitle: const Text(
                        'Cập nhật mật khẩu đăng nhập của bạn.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/change-password'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alternate_email),
                      title: const Text('Đổi email'),
                      subtitle: const Text(
                        'Gửi liên kết xác nhận tới email mới của bạn.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChangeEmail,
                    ),
                    const Divider(),
                    // Notification preferences — each toggle persists on its
                    // own via updateProfile (no need to tap "Lưu thay đổi").
                    Padding(
                      padding: const EdgeInsets.only(
                        top: BananSpacing.sm,
                        bottom: BananSpacing.xs,
                      ),
                      child: Text(
                        'Thông báo',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _marketingOptIn,
                      onChanged: _savingPrefs
                          ? null
                          : (v) => _togglePref(marketing: v),
                      title: const Text('Nhận khuyến mãi & tin mới'),
                      subtitle: const Text(
                        'Ưu đãi, sản phẩm mới và bản tin từ Banan.',
                      ),
                      secondary: const Icon(Icons.campaign_outlined),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _orderUpdatesOptIn,
                      onChanged: _savingPrefs
                          ? null
                          : (v) => _togglePref(orderUpdates: v),
                      title: const Text('Cập nhật trạng thái đơn hàng'),
                      subtitle: const Text(
                        'Thông báo khi đơn của bạn được xử lý & giao.',
                      ),
                      secondary: const Icon(Icons.local_shipping_outlined),
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    const Divider(),
                    const SizedBox(height: BananSpacing.sm),
                    // Destructive: self-service account deletion.
                    OutlinedButton.icon(
                      onPressed: _openDeleteAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Xoá tài khoản'),
                    ),
                    const SizedBox(height: BananSpacing.lg),
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

/// Bottom-sheet to start an email change: "Email mới" + "Mật khẩu hiện tại".
/// On success the backend emails a confirmation link to the new address;
/// we pop with `true` so the profile screen can show the "check your inbox"
/// message. Maps 409 → "đã được sử dụng", 401 → "mật khẩu không đúng".
class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(AppFailure f) {
    if (f is ServerFailure && f.code == 'AUTH_EMAIL_TAKEN') {
      return 'Email đã được sử dụng.';
    }
    if (f is AuthFailure && f.code == 'AUTH_INVALID_CREDENTIALS') {
      return 'Mật khẩu không đúng.';
    }
    if (f is ValidationFailure) {
      return f.message ?? 'Email không hợp lệ hoặc trùng email hiện tại.';
    }
    return authFailureMessage(f);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ref.read(authRepositoryProvider).requestEmailChange(
          newEmail: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = _messageFor(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BananSpacing.lg,
        0,
        BananSpacing.lg,
        bottom + BananSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đổi email', style: theme.textTheme.titleLarge),
            const SizedBox(height: BananSpacing.xs),
            Text(
              'Chúng tôi sẽ gửi liên kết xác nhận tới email mới. '
              'Email chỉ thay đổi sau khi bạn xác nhận.',
              style: theme.textTheme.bodySmall,
            ),
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
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email mới',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'Vui lòng nhập email mới';
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Email không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: BananSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Vui lòng nhập mật khẩu hiện tại'
                  : null,
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
                  : const Icon(Icons.send_outlined),
              label: const Text('Gửi liên kết xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Destructive confirmation dialog for self-service account deletion. Warns
/// the action is irreversible (old orders are anonymised), requires the
/// current password, and pops with `true` once the backend confirms (204).
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu để xác nhận.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res =
        await ref.read(authRepositoryProvider).deleteAccount(_password.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _error = f is AuthFailure && f.code == 'AUTH_INVALID_CREDENTIALS'
            ? 'Mật khẩu không đúng.'
            : authFailureMessage(f);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Xoá tài khoản'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hành động này không thể hoàn tác. Đơn hàng cũ được ẩn danh.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BananSpacing.md),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: BananSpacing.sm),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Xoá vĩnh viễn'),
        ),
      ],
    );
  }
}
