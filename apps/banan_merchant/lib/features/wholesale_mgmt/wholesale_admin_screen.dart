import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _accountsProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).adminAccounts();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _wholesaleOrdersProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).adminOrders();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _receivablesProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).adminReceivables();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _currency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
);

class WholesaleAdminScreen extends ConsumerWidget {
  const WholesaleAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
      next.whenData((event) {
        if (event.event == 'order.created') {
          ref
            ..invalidate(_wholesaleOrdersProvider)
            ..invalidate(_receivablesProvider);
        }
      });
    });
    return MerchantShell(
      title: 'Wholesale',
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Tài khoản & hợp đồng'),
                Tab(text: 'Đơn chờ xử lý'),
                Tab(text: 'Công nợ'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AccountsTab(ref: ref),
                  _OrdersTab(ref: ref),
                  _ReceivablesTab(ref: ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_accountsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_accountsProvider),
      ),
      data: (accounts) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAccountForm(context, ref),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Thêm khách wholesale'),
        ),
        body: accounts.isEmpty
            ? const EmptyState(
                title: 'Chưa có khách wholesale',
                message:
                    'Tạo tài khoản, sau đó thiết lập hợp đồng và danh mục được đặt.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_accountsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final account = accounts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child:
                            Icon(account.active ? Icons.business : Icons.block),
                      ),
                      title: Text(account.companyName),
                      subtitle: Text(
                        '${account.userEmail ?? account.userPhone ?? 'Chưa có liên hệ'} · '
                        '${account.contractCount} hợp đồng · ${account.orderCount} đơn',
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              account.active ? 'Đang hoạt động' : 'Đã khóa',
                            ),
                            avatar: Icon(
                              account.active
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              size: 18,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _openAccountDetail(context, ref, account.id),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_wholesaleOrdersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_wholesaleOrdersProvider),
      ),
      data: (orders) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_wholesaleOrdersProvider),
        child: orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  EmptyState(
                    title: 'Chưa có đơn wholesale',
                    message: 'Đơn khách đặt sẽ xuất hiện tại đây.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final order = orders[index];
                  final pending = order.status == 'PENDING';
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                      '${order.code} · ${order.wholesaleCompanyName ?? 'Wholesale'}',
                    ),
                    subtitle: Text(
                      '${order.items.length} món · ${_currency.format(order.total)} · '
                      '${DateFormat('dd/MM HH:mm').format(order.createdAt.toLocal())}',
                    ),
                    trailing: pending
                        ? Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _rejectWholesale(context, ref, order.id),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Từ chối'),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _confirmWholesale(context, ref, order.id),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Xác nhận & gửi bếp'),
                              ),
                            ],
                          )
                        : Chip(label: Text(_orderState(order.status))),
                  );
                },
              ),
      ),
    );
  }
}

class _ReceivablesTab extends StatelessWidget {
  const _ReceivablesTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_receivablesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_receivablesProvider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_receivablesProvider),
        child: rows.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  EmptyState(
                    title: 'Chưa có công nợ',
                    message: 'Công nợ phát sinh khi khách đặt đơn.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  final due = row.dueDate == null
                      ? 'Chờ xác nhận đơn'
                      : 'Hạn ${DateFormat('dd/MM/yyyy').format(row.dueDate!.toLocal())}';
                  return ListTile(
                    leading: Icon(
                      row.isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.account_balance_wallet_outlined,
                      color: row.isOverdue
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    title: Text(
                      '${row.companyName ?? 'Wholesale'} · ${row.orderCode ?? ''}',
                    ),
                    subtitle: Text('${_currency.format(row.amountVnd)} · $due'),
                    trailing: row.isOpen
                        ? FilledButton.tonal(
                            onPressed: () => _markPaid(context, ref, row.id),
                            child: const Text('Xác nhận đã thu'),
                          )
                        : Chip(label: Text(_receivableState(row.status))),
                  );
                },
              ),
      ),
    );
  }
}

Future<void> _confirmWholesale(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận đơn wholesale?'),
      content: const Text(
        'Đơn sẽ được đưa vào bếp và bắt đầu kỳ hạn công nợ theo hợp đồng.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  if (approved != true || !context.mounted) return;
  final result = await ref.read(wholesaleApiProvider).adminConfirmOrder(id);
  if (!context.mounted) return;
  result.when(
    success: (_) {
      ref
        ..invalidate(_wholesaleOrdersProvider)
        ..invalidate(_receivablesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận và gửi đơn vào bếp.')),
      );
    },
    failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message ?? failure.code)),
    ),
  );
}

/// Collection dialog: amount (blank = full remaining), method, bank
/// reference, note. Sends a per-attempt dedup key so a double-tap can't
/// record the same collection twice.
Future<void> _markPaid(BuildContext context, WidgetRef ref, String id) async {
  final amountCtl = TextEditingController();
  final refCtl = TextEditingController();
  final noteCtl = TextEditingController();
  var method = 'BANK_TRANSFER';
  final requestKey =
      'pay-${DateTime.now().millisecondsSinceEpoch}-${UniqueKey().hashCode}';
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ghi nhận thu tiền'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền (đ)',
                helperText: 'Bỏ trống = thu toàn bộ phần còn lại',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            StatefulBuilder(
              builder: (context, setState) => DropdownButtonFormField<String>(
                initialValue: method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Phương thức'),
                items: const [
                  DropdownMenuItem(
                    value: 'BANK_TRANSFER',
                    child: Text('Chuyển khoản'),
                  ),
                  DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                  DropdownMenuItem(value: 'CARD', child: Text('Thẻ')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => method = v ?? 'BANK_TRANSFER'),
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: refCtl,
              decoration: const InputDecoration(
                labelText: 'Mã giao dịch ngân hàng (tuỳ chọn)',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: noteCtl,
              decoration:
                  const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ghi nhận'),
        ),
      ],
    ),
  );
  if (approved != true || !context.mounted) return;
  final amount = int.tryParse(amountCtl.text.replaceAll(RegExp('[^0-9]'), ''));
  final result = await ref.read(wholesaleApiProvider).adminRecordPayment(
        id,
        amountVnd: amount,
        method: method,
        reference: refCtl.text.trim(),
        note: noteCtl.text.trim(),
        clientRequestId: requestKey,
      );
  if (!context.mounted) return;
  result.when(
    success: (_) {
      ref.invalidate(_receivablesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận thu tiền công nợ.')),
      );
    },
    failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message ?? failure.code)),
    ),
  );
}

Future<void> _rejectWholesale(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final controller = TextEditingController();
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Từ chối đơn wholesale?'),
      content: TextField(
        controller: controller,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Lý do (tùy chọn)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Từ chối đơn'),
        ),
      ],
    ),
  );
  if (approved != true || !context.mounted) {
    controller.dispose();
    return;
  }
  final result = await ref
      .read(wholesaleApiProvider)
      .adminRejectOrder(id, reason: controller.text.trim());
  controller.dispose();
  if (!context.mounted) return;
  result.when(
    success: (_) {
      ref
        ..invalidate(_wholesaleOrdersProvider)
        ..invalidate(_receivablesProvider);
    },
    failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message ?? failure.code)),
    ),
  );
}

Future<void> _openAccountForm(BuildContext context, WidgetRef ref) async {
  final result =
      await ref.read(adminRepositoryProvider).listUsers(perPage: 200);
  if (!context.mounted) return;
  final users = result.when(
    success: (page) =>
        page.items.where((user) => user.role == Role.customer).toList(),
    failure: (_) => <AdminUser>[],
  );
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AccountForm(users: users),
  );
  if (created ?? false) ref.invalidate(_accountsProvider);
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({required this.users});
  final List<AdminUser> users;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  String? userId;
  final company = TextEditingController();
  final contact = TextEditingController();
  final address = TextEditingController();
  final credit = TextEditingController();
  final term = TextEditingController(text: '30');
  bool saving = false;

  @override
  void dispose() {
    company.dispose();
    contact.dispose();
    address.dispose();
    credit.dispose();
    term.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (userId == null ||
        company.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Chọn tài khoản, nhập tên công ty và địa chỉ giao hàng.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final result = await ref.read(wholesaleApiProvider).adminCreateAccount({
      'userId': userId,
      'companyName': company.text.trim(),
      if (contact.text.trim().isNotEmpty) 'contactName': contact.text.trim(),
      'deliveryAddress': address.text.trim(),
      'creditLimitVnd':
          int.tryParse(credit.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      'paymentTermDays': int.tryParse(term.text) ?? 30,
    });
    if (!mounted) return;
    setState(() => saving = false);
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? failure.code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tạo khách wholesale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: userId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Tài khoản khách hàng'),
              items: [
                for (final user in widget.users)
                  DropdownMenuItem(
                    value: user.id,
                    child: Text('${user.fullName} · ${user.email}'),
                  ),
              ],
              onChanged: (value) => setState(() => userId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: company,
              decoration: const InputDecoration(labelText: 'Tên công ty'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contact,
              decoration: const InputDecoration(labelText: 'Người liên hệ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Địa chỉ giao hàng'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: credit,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Hạn mức công nợ (đ)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: term,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kỳ hạn thanh toán (ngày)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Tạo tài khoản wholesale'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAccountDetail(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final result = await ref.read(wholesaleApiProvider).adminAccount(id);
  if (!context.mounted) return;
  result.when(
    success: (data) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountDetail(account: data),
    ).then((_) => ref.invalidate(_accountsProvider)),
    failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message ?? failure.code)),
    ),
  );
}

class _AccountDetail extends ConsumerStatefulWidget {
  const _AccountDetail({required this.account});
  final Map<String, dynamic> account;

  @override
  ConsumerState<_AccountDetail> createState() => _AccountDetailState();
}

class _AccountDetailState extends ConsumerState<_AccountDetail> {
  late Map<String, dynamic> account = widget.account;

  Future<void> reload() async {
    final result = await ref
        .read(wholesaleApiProvider)
        .adminAccount(account['id'] as String);
    if (!mounted) return;
    result.when(
      success: (value) => setState(() => account = value),
      failure: (_) {},
    );
  }

  Future<void> toggleAccount() async {
    final active = account['active'] as bool? ?? true;
    final result = await ref.read(wholesaleApiProvider).adminUpdateAccount(
      account['id'] as String,
      {'active': !active},
    );
    if (!mounted) return;
    result.when(
      success: (_) => reload(),
      failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? failure.code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contracts = ((account['contracts'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return FractionallySizedBox(
      heightFactor: .92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account['companyName'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: account['active'] == true
                      ? 'Khóa đặt hàng'
                      : 'Mở lại đặt hàng',
                  onPressed: toggleAccount,
                  icon: Icon(
                    account['active'] == true
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final made = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          _ContractDialog(accountId: account['id'] as String),
                    );
                    if (made ?? false) await reload();
                  },
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Thêm hợp đồng'),
                ),
              ],
            ),
            Text(
              'Hạn mức ${_currency.format(account['creditLimitVnd'] ?? 0)} · '
              '${account['paymentTermDays'] ?? 30} ngày · ${account['deliveryAddress'] ?? 'Chưa có địa chỉ giao'}',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: contracts.isEmpty
                  ? const EmptyState(
                      title: 'Chưa có hợp đồng',
                      message:
                          'Khách chỉ đặt được sau khi có hợp đồng và sản phẩm được phép.',
                    )
                  : ListView.separated(
                      itemCount: contracts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final contract = contracts[index];
                        final lines = ((contract['lines'] as List?) ?? const [])
                            .cast<Map<String, dynamic>>();
                        return ExpansionTile(
                          leading: Icon(
                            contract['active'] == true
                                ? Icons.description_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(contract['name'] as String? ?? ''),
                          subtitle: Text(
                            '${lines.length} sản phẩm · từ ${_date(contract['startsAt'])}${contract['endsAt'] == null ? '' : ' đến ${_date(contract['endsAt'])}'}',
                          ),
                          children: [
                            for (final line in lines)
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.only(left: 72, right: 16),
                                // Tap = edit price/discount/minQty in place —
                                // no more deactivate-and-re-add to change a price.
                                onTap: () async {
                                  final saved = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => _ContractLineEditDialog(
                                      contractId: contract['id'] as String,
                                      line: line,
                                    ),
                                  );
                                  if (saved ?? false) await reload();
                                },
                                title: Text(
                                  (line['product'] as Map?)?['name']
                                          as String? ??
                                      'Sản phẩm',
                                ),
                                subtitle: Text(
                                  [
                                    if (line['variant'] != null)
                                      '${(line['variant'] as Map)['size']} · ${(line['variant'] as Map)['flavor']}',
                                    if (line['fixedPriceVnd'] != null)
                                      _currency.format(
                                        _asNumber(line['fixedPriceVnd']),
                                      )
                                    else
                                      'Chiết khấu ${line['discountPct'] ?? contract['defaultDiscountPct'] ?? 0}%',
                                    'Tối thiểu ${line['minQty'] ?? 1}',
                                  ].join(' · '),
                                ),
                                trailing: Switch(
                                  value: line['active'] as bool? ?? true,
                                  onChanged: (active) async {
                                    await ref
                                        .read(wholesaleApiProvider)
                                        .adminUpdateLine(
                                      contract['id'] as String,
                                      line['id'] as String,
                                      {'active': active},
                                    );
                                    await reload();
                                  },
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(72, 8, 16, 16),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final made = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => _ContractLineDialog(
                                          contractId: contract['id'] as String,
                                        ),
                                      );
                                      if (made ?? false) await reload();
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Thêm sản phẩm'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await ref
                                          .read(wholesaleApiProvider)
                                          .adminUpdateContract(
                                        contract['id'] as String,
                                        {'active': contract['active'] != true},
                                      );
                                      await reload();
                                    },
                                    icon: Icon(
                                      contract['active'] == true
                                          ? Icons.archive_outlined
                                          : Icons.unarchive_outlined,
                                    ),
                                    label: Text(
                                      contract['active'] == true
                                          ? 'Ngừng hợp đồng'
                                          : 'Mở lại hợp đồng',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractDialog extends ConsumerStatefulWidget {
  const _ContractDialog({required this.accountId});
  final String accountId;
  @override
  ConsumerState<_ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends ConsumerState<_ContractDialog> {
  final name = TextEditingController();
  final discount = TextEditingController();
  final minOrder = TextEditingController();
  final term = TextEditingController();
  DateTime startsAt = DateTime.now();

  @override
  void dispose() {
    name.dispose();
    discount.dispose();
    minOrder.dispose();
    term.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final result = await ref.read(wholesaleApiProvider).adminCreateContract({
      'wholesaleAccountId': widget.accountId,
      'name': name.text.trim(),
      'startsAt': startsAt.toUtc().toIso8601String(),
      if (discount.text.isNotEmpty)
        'defaultDiscountPct': double.tryParse(discount.text),
      if (minOrder.text.isNotEmpty)
        'minOrderVnd':
            int.tryParse(minOrder.text.replaceAll(RegExp(r'\D'), '')),
      if (term.text.isNotEmpty) 'paymentTermDays': int.tryParse(term.text),
    });
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? failure.code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Hợp đồng mới'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên hợp đồng'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Chiết khấu mặc định (%)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá trị đơn tối thiểu (đ)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: term,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kỳ hạn riêng (ngày, tùy chọn)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(onPressed: save, child: const Text('Tạo hợp đồng')),
        ],
      );
}

class _ContractLineDialog extends ConsumerStatefulWidget {
  const _ContractLineDialog({required this.contractId});
  final String contractId;
  @override
  ConsumerState<_ContractLineDialog> createState() =>
      _ContractLineDialogState();
}

class _ContractLineDialogState extends ConsumerState<_ContractLineDialog> {
  List<Product> products = const [];
  Product? product;
  ProductVariant? variant;
  final fixedPrice = TextEditingController();
  final discount = TextEditingController();
  final minQty = TextEditingController(text: '1');
  final leadTime = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final result =
          await ref.read(catalogRepositoryProvider).merchantProducts();
      if (!mounted) return;
      result.when(
        success: (page) => setState(() => products = page.items),
        failure: (_) {},
      );
    });
  }

  @override
  void dispose() {
    fixedPrice.dispose();
    discount.dispose();
    minQty.dispose();
    leadTime.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (product == null) return;
    final result =
        await ref.read(wholesaleApiProvider).adminAddLine(widget.contractId, {
      'productId': product!.id,
      if (variant != null) 'variantId': variant!.id,
      if (fixedPrice.text.isNotEmpty)
        'fixedPriceVnd':
            int.tryParse(fixedPrice.text.replaceAll(RegExp(r'\D'), '')),
      if (discount.text.isNotEmpty)
        'discountPct': double.tryParse(discount.text),
      'minQty': int.tryParse(minQty.text) ?? 1,
      if (leadTime.text.isNotEmpty)
        'leadTimeHours': int.tryParse(leadTime.text),
    });
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? failure.code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Thêm sản phẩm được đặt'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  initialValue: product,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sản phẩm'),
                  items: [
                    for (final value in products)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) => setState(() {
                    product = value;
                    variant = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductVariant?>(
                  initialValue: variant,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Biến thể (bỏ trống = mọi biến thể)',
                  ),
                  items: [
                    const DropdownMenuItem<ProductVariant?>(
                      value: null,
                      child: Text('Mọi biến thể'),
                    ),
                    for (final value
                        in product?.variants ?? const <ProductVariant>[])
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) => setState(() => variant = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fixedPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá hợp đồng cố định (đ, tùy chọn)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chiết khấu riêng (%, tùy chọn)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minQty,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Số lượng tối thiểu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: leadTime,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Đặt trước tối thiểu (giờ)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(onPressed: save, child: const Text('Thêm sản phẩm')),
        ],
      );
}

/// Edit an EXISTING contract line: fixed price / discount % / minQty /
/// lead time. Product + variant stay fixed (add a new line for a different
/// product); PATCHes via adminUpdateLine.
class _ContractLineEditDialog extends ConsumerStatefulWidget {
  const _ContractLineEditDialog({required this.contractId, required this.line});
  final String contractId;
  final Map<String, dynamic> line;
  @override
  ConsumerState<_ContractLineEditDialog> createState() =>
      _ContractLineEditDialogState();
}

class _ContractLineEditDialogState
    extends ConsumerState<_ContractLineEditDialog> {
  late final fixedPrice = TextEditingController(
    text: widget.line['fixedPriceVnd'] == null
        ? ''
        : '${_asNumber(widget.line['fixedPriceVnd']).toInt()}',
  );
  late final discount = TextEditingController(
    text: widget.line['discountPct'] == null
        ? ''
        : '${_asNumber(widget.line['discountPct'])}',
  );
  late final minQty =
      TextEditingController(text: '${widget.line['minQty'] ?? 1}');
  late final leadTime = TextEditingController(
    text: widget.line['leadTimeHours'] == null
        ? ''
        : '${widget.line['leadTimeHours']}',
  );

  @override
  void dispose() {
    fixedPrice.dispose();
    discount.dispose();
    minQty.dispose();
    leadTime.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final result = await ref.read(wholesaleApiProvider).adminUpdateLine(
      widget.contractId,
      widget.line['id'] as String,
      {
        if (fixedPrice.text.trim().isNotEmpty)
          'fixedPriceVnd':
              int.tryParse(fixedPrice.text.replaceAll(RegExp(r'\D'), ''))
        else
          'fixedPriceVnd': null,
        if (discount.text.trim().isNotEmpty)
          'discountPct': double.tryParse(discount.text)
        else
          'discountPct': null,
        'minQty': int.tryParse(minQty.text) ?? 1,
        if (leadTime.text.trim().isNotEmpty)
          'leadTimeHours': int.tryParse(leadTime.text)
        else
          'leadTimeHours': null,
      },
    );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? failure.code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productName =
        (widget.line['product'] as Map?)?['name'] as String? ?? 'Sản phẩm';
    return AlertDialog(
      title: Text('Sửa giá · $productName'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fixedPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá hợp đồng cố định (đ)',
                helperText: 'Bỏ trống để dùng chiết khấu %',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Chiết khấu riêng (%)',
                helperText: 'Bỏ trống = dùng chiết khấu mặc định của hợp đồng',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minQty,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Số lượng tối thiểu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: leadTime,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Đặt trước tối thiểu (giờ)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: save, child: const Text('Lưu')),
      ],
    );
  }
}

String _date(dynamic value) => value == null
    ? ''
    : DateFormat('dd/MM/yyyy').format(DateTime.parse('$value').toLocal());

num _asNumber(dynamic value) =>
    value is num ? value : num.tryParse('$value') ?? 0;

String _orderState(String status) => switch (status) {
      'PENDING' => 'Đã đặt đơn',
      'DELIVERING' => 'Đang giao hàng',
      'CANCELLED' => 'Đã hủy',
      _ => 'Đã xác nhận',
    };

String _receivableState(String status) => switch (status) {
      'PENDING' => 'Chờ xác nhận đơn',
      'PAID' => 'Đã thanh toán',
      'CANCELLED' => 'Đã hủy',
      'OVERDUE' => 'Quá hạn',
      _ => status,
    };
