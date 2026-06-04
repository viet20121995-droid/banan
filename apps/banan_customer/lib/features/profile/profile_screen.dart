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
  bool _hydrated = false;
  bool _saving = false;
  String? _error;

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
