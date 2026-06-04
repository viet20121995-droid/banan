import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Current search term for the customer directory.
final customerSearchProvider = StateProvider<String>((_) => '');

final customersListProvider =
    FutureProvider.autoDispose<CustomerPage>((ref) async {
  final q = ref.watch(customerSearchProvider);
  final res = await ref
      .watch(customersRepositoryProvider)
      .list(q: q.isEmpty ? null : q, perPage: 50);
  return res.when(
    success: (page) => page,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() =>
      _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersListProvider);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return MerchantShell(
      title: 'Khách hàng',
      onRefresh: () async => ref.invalidate(customersListProvider),
      action: IconButton(
        icon: const Icon(Icons.campaign_outlined),
        tooltip: 'Gửi thông báo hàng loạt',
        onPressed: () => _openBroadcast(context, ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Khách hàng mới'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, số điện thoại hoặc email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        ref.read(customerSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => ref
                .read(customerSearchProvider.notifier)
                .state = v.trim(),
          ),
          const SizedBox(height: BananSpacing.md),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(customersListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    title: 'Chưa có khách hàng',
                    message:
                        'Khách đặt hàng tại cửa hàng của bạn sẽ hiện ở đây.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(customersListProvider),
                  child: ListView.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (_, i) {
                      final c = page.items[i];
                      return _CustomerRow(customer: c, money: money);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBroadcast(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final tag = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi thông báo hàng loạt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              TextField(
                controller: body,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nội dung'),
              ),
              TextField(
                controller: tag,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Nhãn (tuỳ chọn — vd VIP)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiêu đề và nội dung là bắt buộc.')),
      );
      return;
    }
    final res = await ref.read(customersRepositoryProvider).broadcast(
          title: title.text.trim(),
          body: body.text.trim(),
          tag: tag.text.trim().isEmpty ? null : tag.text.trim(),
        );
    if (!context.mounted) return;
    res.when(
      success: (n) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi tới $n khách hàng.')),
      ),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  /// Quick-add dialog for phone customers — captures name + phone (+
  /// optional email & notes) and POSTs `/merchant/customers`.
  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khách hàng mới'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                TextField(
                  controller: phone,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Dùng để định danh — khách đặt cùng SĐT '
                        'lần sau sẽ tự liên kết.',
                  ),
                ),
                TextField(
                  controller: email,
                  maxLength: 160,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (tuỳ chọn)',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLength: 280,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (chỉ nội bộ)',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().length < 2 || phone.text.trim().length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần tên và số điện thoại hợp lệ.')),
      );
      return;
    }
    final res = await ref.read(customersApiProvider).create(
          fullName: name.text.trim(),
          phone: phone.text.trim(),
          email: email.text.trim().isEmpty ? null : email.text.trim(),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo khách hàng "${name.text.trim()}".')),
        );
        ref.invalidate(customersListProvider);
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        );
      },
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.money});
  final CustomerSummary customer;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = customer.fullName.trim().isEmpty
        ? '?'
        : customer.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BananRadii.rmd,
      child: InkWell(
        borderRadius: BananRadii.rmd,
        onTap: () => context.push('/customers/${customer.id}'),
        child: Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            border: Border.all(
                color: theme.dividerTheme.color ?? Colors.black12,),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: BananColors.gold,
                backgroundImage: (customer.avatarUrl != null &&
                        customer.avatarUrl!.isNotEmpty)
                    ? NetworkImage(customer.avatarUrl!)
                    : null,
                child: (customer.avatarUrl == null ||
                        customer.avatarUrl!.isEmpty)
                    ? Text(initials,
                        style: const TextStyle(color: Colors.white),)
                    : null,
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.fullName,
                        style: theme.textTheme.titleSmall,),
                    Text(
                      customer.phone ?? customer.email,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (customer.tags.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: BananSpacing.xs),
                        child: Wrap(
                          spacing: BananSpacing.xs,
                          children: [
                            for (final t in customer.tags.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1,),
                                decoration: BoxDecoration(
                                  color: BananColors.gold
                                      .withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: BananSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${customer.orderCount} orders',
                      style: theme.textTheme.labelMedium,),
                  Text(
                    money.format(customer.totalSpentVnd),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
