import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _usersProvider =
    FutureProvider.autoDispose<AdminUserPage>((ref) async {
  final res = await ref.watch(adminRepositoryProvider).listUsers(perPage: 100);
  return res.when(
    success: (p) => p,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

final _storesProvider =
    FutureProvider.autoDispose<List<OrgOption>>((ref) async {
  final res = await ref.watch(adminRepositoryProvider).stores();
  return res.when(success: (l) => l, failure: (_) => const []);
});

final _kitchensProvider =
    FutureProvider.autoDispose<List<OrgOption>>((ref) async {
  final res = await ref.watch(adminRepositoryProvider).kitchens();
  return res.when(success: (l) => l, failure: (_) => const []);
});

const _provisionable = <Role>[
  Role.customer,
  Role.merchantOwner,
  Role.merchantStaff,
  Role.kitchenManager,
  Role.kitchenStaff,
];

String _roleLabel(Role r) => switch (r) {
      Role.customer => 'Khách hàng',
      Role.merchantOwner => 'Chủ cửa hàng (Merchant)',
      Role.merchantStaff => 'Nhân viên cửa hàng (Merchant)',
      Role.kitchenManager => 'Quản lý bếp',
      Role.kitchenStaff => 'Nhân viên bếp',
      Role.admin => 'Admin',
    };

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_usersProvider);
    return MerchantShell(
      title: 'Tài khoản',
      onRefresh: () async => ref.invalidate(_usersProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tạo tài khoản'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_usersProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(
              title: 'Chưa có tài khoản',
              message: 'Tạo tài khoản merchant, bếp hoặc khách hàng.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_usersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: page.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.sm),
              itemBuilder: (_, i) => _UserRow(user: page.items[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateUserSheet(),
    );
    if (created ?? false) ref.invalidate(_usersProvider);
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = user.storeName ?? user.kitchenName;
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: BananColors.gold,
            child: Text(
              user.fullName.isEmpty
                  ? '?'
                  : user.fullName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: theme.textTheme.titleSmall),
                Text(user.email, style: theme.textTheme.bodySmall),
                if (user.phone != null)
                  Text(user.phone!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_roleLabel(user.role),
                    style: theme.textTheme.labelSmall,),
              ),
              if (scope != null) ...[
                const SizedBox(height: 2),
                Text(scope, style: theme.textTheme.labelSmall),
              ],
              Text(
                DateFormat.yMMMd().format(user.createdAt.toLocal()),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Role _role = Role.customer;
  String? _storeId;
  String? _kitchenId;
  bool _saving = false;
  String? _error;

  bool get _needsStore =>
      _role == Role.merchantOwner || _role == Role.merchantStaff;
  bool get _needsKitchen =>
      _role == Role.kitchenManager || _role == Role.kitchenStaff;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsStore && _storeId == null) {
      setState(() => _error = 'Chọn cửa hàng cho tài khoản merchant.');
      return;
    }
    if (_needsKitchen && _kitchenId == null) {
      setState(() => _error = 'Chọn bếp cho tài khoản bếp.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref.read(adminRepositoryProvider).createUser(
          NewUserDraft(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            role: _role,
            storeId: _needsStore ? _storeId : null,
            kitchenId: _needsKitchen ? _kitchenId : null,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final stores = ref.watch(_storesProvider).valueOrNull ?? const [];
    final kitchens = ref.watch(_kitchensProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          BananSpacing.lg, 0, BananSpacing.lg, bottom + BananSpacing.lg,),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Tạo tài khoản', style: theme.textTheme.titleLarge),
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
            DropdownButtonFormField<Role>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Loại tài khoản'),
              items: [
                for (final r in _provisionable)
                  DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
              ],
              onChanged: (r) => setState(() {
                _role = r ?? Role.customer;
                _storeId = null;
                _kitchenId = null;
              }),
            ),
            const SizedBox(height: BananSpacing.sm),
            if (_needsStore)
              DropdownButtonFormField<String>(
                initialValue: _storeId,
                decoration: const InputDecoration(labelText: 'Cửa hàng'),
                items: [
                  for (final o in stores)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() => _storeId = v),
              ),
            if (_needsKitchen)
              DropdownButtonFormField<String>(
                initialValue: _kitchenId,
                decoration: const InputDecoration(labelText: 'Bếp'),
                items: [
                  for (final o in kitchens)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() => _kitchenId = v),
              ),
            if (_needsStore || _needsKitchen)
              const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Số điện thoại (tuỳ chọn)',),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Mật khẩu (tối thiểu 8 ký tự)',),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Tối thiểu 8 ký tự' : null,
            ),
            const SizedBox(height: BananSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}
