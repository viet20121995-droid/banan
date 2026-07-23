import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _catalogProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).catalog();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _ordersProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).myOrders();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _debtsProvider = FutureProvider.autoDispose((ref) async {
  final result = await ref.watch(wholesaleApiProvider).myReceivables();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw Exception(failure.message ?? failure.code),
  );
});

final _money =
    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

class WholesaleScreen extends StatelessWidget {
  const WholesaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đặt hàng sỉ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Đặt hàng'),
              Tab(text: 'Đơn của tôi'),
              Tab(text: 'Công nợ'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CatalogTab(), _MyOrdersTab(), _MyDebtsTab()],
        ),
      ),
    );
  }
}

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab();

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  final quantities = <String, int>{};
  final notes = TextEditingController();
  final poCode = TextEditingController();
  DateTime? scheduledFor;
  bool saving = false;
  // One dedup key per cart attempt: a double-tap or network retry re-sends
  // the SAME key and the backend returns the first order. Regenerated after
  // each successful submit (a new cart = a new order).
  String _requestKey =
      'wh-${DateTime.now().millisecondsSinceEpoch}-${UniqueKey().hashCode}';

  @override
  void dispose() {
    notes.dispose();
    poCode.dispose();
    super.dispose();
  }

  Future<void> submit(WholesaleContractView contract) async {
    final selected =
        contract.lines.where((line) => (quantities[line.id] ?? 0) > 0).toList();
    if (selected.isEmpty) {
      _message('Chọn ít nhất một sản phẩm.');
      return;
    }
    if (contract.requiresDeliveryDate && scheduledFor == null) {
      _message('Hợp đồng này yêu cầu chọn ngày giao hàng.');
      return;
    }
    setState(() => saving = true);
    final result = await ref.read(wholesaleApiProvider).createOrder(
          contractId: contract.id,
          items: [
            for (final line in selected)
              {
                'productId': line.productId,
                if (line.variantId != null) 'variantId': line.variantId,
                'quantity': quantities[line.id],
              },
          ],
          scheduledFor: scheduledFor,
          notes: notes.text.trim(),
          poCode: poCode.text.trim(),
          clientRequestId: _requestKey,
        );
    if (!mounted) return;
    setState(() => saving = false);
    result.when(
      success: (order) {
        quantities.clear();
        notes.clear();
        poCode.clear();
        scheduledFor = null;
        _requestKey =
            'wh-${DateTime.now().millisecondsSinceEpoch}-${UniqueKey().hashCode}';
        setState(() {});
        ref
          ..invalidate(_ordersProvider)
          ..invalidate(_debtsProvider);
        _message('Đã đặt ${order.code}. Đơn đang chờ admin xác nhận.');
      },
      failure: (failure) => _message(failure.message ?? failure.code),
    );
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_catalogProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 44),
              const SizedBox(height: 12),
              const Text('Tài khoản chưa được phép đặt sỉ.'),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(_catalogProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (contracts) => contracts.isEmpty
          ? const EmptyState(
              title: 'Chưa có hợp đồng hiệu lực',
              message:
                  'Liên hệ Banan để kiểm tra thời hạn và danh mục hợp đồng.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contracts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (_, index) => _ContractOrderForm(
                contract: contracts[index],
                quantities: quantities,
                notes: notes,
                poCode: poCode,
                scheduledFor: scheduledFor,
                saving: saving,
                onQuantity: (line, quantity) => setState(() {
                  if (quantity <= 0) {
                    quantities.remove(line.id);
                  } else {
                    quantities[line.id] = quantity;
                  }
                }),
                onSchedule: (value) => setState(() => scheduledFor = value),
                onSubmit: () => submit(contracts[index]),
              ),
            ),
    );
  }
}

class _ContractOrderForm extends StatelessWidget {
  const _ContractOrderForm({
    required this.contract,
    required this.quantities,
    required this.notes,
    required this.poCode,
    required this.scheduledFor,
    required this.saving,
    required this.onQuantity,
    required this.onSchedule,
    required this.onSubmit,
  });

  final WholesaleContractView contract;
  final Map<String, int> quantities;
  final TextEditingController notes;
  final TextEditingController poCode;
  final DateTime? scheduledFor;
  final bool saving;
  final void Function(WholesaleCatalogLine, int) onQuantity;
  final ValueChanged<DateTime?> onSchedule;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final goods = contract.lines.fold<double>(
      0,
      (sum, line) => sum + line.contractPrice * (quantities[line.id] ?? 0),
    );
    // Ship fee is per order — only shown/charged once something is in the cart.
    final total = goods + (goods > 0 ? contract.shipFeeVnd : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(contract.name, style: Theme.of(context).textTheme.titleLarge),
        if (contract.minOrderVnd != null)
          Text('Giá trị tối thiểu ${_money.format(contract.minOrderVnd)}'),
        const SizedBox(height: 12),
        for (final line in contract.lines) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(line.productName),
            subtitle: Text(
              [
                if (line.variantLabel != null) line.variantLabel!,
                'Giá hợp đồng ${_money.format(line.contractPrice)}',
                'Tối thiểu ${line.minQty}',
                if (line.multipleQty > 1) 'Bội số ${line.multipleQty}',
                if (line.deliveryDays.isNotEmpty)
                  'Chỉ giao ${_dayNames(line.deliveryDays)}',
                if (line.leadTimeDays != null && line.leadTimeDays! > 0)
                  'Đặt trước ${line.leadTimeDays} ngày',
                if (line.leadTimeHours != null)
                  'Đặt trước ${line.leadTimeHours} giờ',
              ].join(' · '),
            ),
            trailing: _QuantityControl(
              value: quantities[line.id] ?? 0,
              minimum: line.minQty,
              step: line.multipleQty,
              onChanged: (value) => onQuantity(line, value),
            ),
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            var earliest = DateTime(now.year, now.month, now.day);
            // Next-day cutoff: order before HH:mm → tomorrow, after → +2 days.
            final cutoff = contract.nextDayCutoffMinutes;
            if (cutoff != null) {
              earliest = earliest.add(
                Duration(days: now.hour * 60 + now.minute < cutoff ? 1 : 2),
              );
            }
            // Selected items with a lead-time in days push the earliest date.
            for (final line in contract.lines) {
              final lead = line.leadTimeDays ?? 0;
              if ((quantities[line.id] ?? 0) > 0 && lead > 0) {
                final leadDay =
                    DateTime(now.year, now.month, now.day).add(Duration(days: lead));
                if (leadDay.isAfter(earliest)) earliest = leadDay;
              }
            }
            bool selectable(DateTime d) =>
                !contract.noDeliveryDays.contains(d.weekday);
            var initial = scheduledFor ?? earliest;
            if (initial.isBefore(earliest)) initial = earliest;
            while (!selectable(initial)) {
              initial = initial.add(const Duration(days: 1));
            }
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: earliest,
              lastDate: now.add(const Duration(days: 180)),
              selectableDayPredicate: selectable,
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(scheduledFor ?? now),
            );
            if (time == null) return;
            onSchedule(
              DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              ),
            );
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(
            scheduledFor == null
                ? (contract.requiresDeliveryDate
                    ? 'Chọn ngày giao (bắt buộc)'
                    : 'Chọn thời gian cần giao')
                : 'Giao ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledFor!)}',
          ),
        ),
        if (contract.nextDayCutoffMinutes != null ||
            contract.noDeliveryDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                if (contract.nextDayCutoffMinutes != null)
                  'Đặt trước ${_hhmm(contract.nextDayCutoffMinutes!)} để được '
                      'giao vào ngày hôm sau.',
                if (contract.noDeliveryDays.isNotEmpty)
                  'Không giao vào ${_dayNames(contract.noDeliveryDays)}.',
              ].join(' '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: poCode,
          decoration: const InputDecoration(
            labelText: 'Mã đơn mua hàng (PO), tuỳ chọn',
            helperText: 'Mã PO nội bộ của công ty bạn, in kèm đơn để đối soát.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Ghi chú đơn hàng'),
        ),
        const SizedBox(height: 16),
        if (contract.shipFeeVnd > 0 && goods > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Phí giao hàng: ${_money.format(contract.shipFeeVnd)}',
              textAlign: TextAlign.end,
            ),
          ),
        FilledButton.icon(
          onPressed: saving ? null : onSubmit,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text('Đặt theo công nợ · ${_money.format(total)}'),
        ),
      ],
    );
  }
}

const _weekdayVi = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
String _dayNames(List<int> days) => days.map((d) => _weekdayVi[d]).join(', ');
String _hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.value,
    required this.minimum,
    required this.onChanged,
    this.step = 1,
  });
  final int value;
  final int minimum;

  /// Quantity moves in multiples of this (contract line multipleQty).
  final int step;
  final ValueChanged<int> onChanged;

  /// First orderable quantity: the minimum rounded UP to a multiple of step.
  int get _first => ((minimum + step - 1) ~/ step) * step;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm',
            onPressed: value == 0
                ? null
                : () => onChanged(value <= _first ? 0 : value - step),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 30,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: 'Tăng',
            onPressed: () => onChanged(value == 0 ? _first : value + step),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
}

class _MyOrdersTab extends ConsumerWidget {
  const _MyOrdersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_ordersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_ordersProvider),
      ),
      data: (orders) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_ordersProvider),
        child: orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyState(
                    title: 'Chưa có đơn',
                    message: 'Đơn sỉ đã đặt sẽ hiển thị tại đây.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final order = orders[index];
                  return ListTile(
                    leading: Icon(_statusIcon(order.status)),
                    title: Text(order.code),
                    subtitle: Text(
                      '${order.items.length} món · ${_money.format(order.total)}',
                    ),
                    trailing: order.status == 'PENDING'
                        ? TextButton.icon(
                            onPressed: () async {
                              final result =
                                  await ref.read(ordersApiProvider).cancel(
                                        order.id,
                                        reason: 'Khách wholesale hủy',
                                      );
                              if (!context.mounted) return;
                              result.when(
                                success: (_) {
                                  ref
                                    ..invalidate(_ordersProvider)
                                    ..invalidate(_debtsProvider);
                                },
                                failure: (failure) =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(failure.message ?? failure.code),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Hủy đơn'),
                          )
                        : Chip(label: Text(_status(order.status))),
                  );
                },
              ),
      ),
    );
  }
}

class _MyDebtsTab extends ConsumerWidget {
  const _MyDebtsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_debtsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_debtsProvider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_debtsProvider),
        child: rows.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyState(
                    title: 'Chưa có công nợ',
                    message: 'Công nợ theo hợp đồng sẽ hiển thị tại đây.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: Icon(
                      row.isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_long_outlined,
                    ),
                    title: Text(
                      '${row.orderCode ?? 'Đơn hàng'} · ${_money.format(row.amountVnd)}',
                    ),
                    subtitle: Text(
                      row.dueDate == null
                          ? 'Kỳ hạn bắt đầu sau khi đơn được xác nhận'
                          : 'Hạn thanh toán ${DateFormat('dd/MM/yyyy').format(row.dueDate!.toLocal())}',
                    ),
                    trailing: Chip(
                      label: Text(_debtStatus(row.status, row.isOverdue)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

String _status(String value) => switch (value) {
      'PENDING' => 'Đã đặt đơn',
      'DELIVERING' => 'Đang giao hàng',
      'CANCELLED' => 'Đã hủy',
      _ => 'Đã xác nhận',
    };

IconData _statusIcon(String value) => switch (value) {
      'PENDING' => Icons.schedule_outlined,
      'DELIVERING' => Icons.local_shipping_outlined,
      'CANCELLED' => Icons.cancel_outlined,
      _ => Icons.check_circle_outline,
    };

String _debtStatus(String status, bool overdue) {
  if (overdue) return 'Quá hạn';
  return switch (status) {
    'PENDING' => 'Chờ xác nhận đơn',
    'PAID' => 'Đã thanh toán',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa thanh toán',
  };
}
