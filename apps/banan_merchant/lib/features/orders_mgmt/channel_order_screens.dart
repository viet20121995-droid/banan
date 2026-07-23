import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Staff-entered order flows that reuse the normal Order pipeline:
///  * [CounterOrderScreen] — "Tạo đơn tại quầy": walk-in customer, settled at
///    the till (paid or to-collect), pushed straight onto the kitchen board.
///  * [InternalTransferScreen] — "Đặt hàng nội bộ": a branch requests goods
///    from the kitchen for itself; no customer, no payment, no benefits.
/// Both are store-scoped server-side; the dedup key makes a double-tap safe.

final _money = NumberFormat.decimalPattern('vi_VN');

class _CartLine {
  _CartLine(this.product, this.variant, this.qty);
  final Product product;
  final ProductVariant variant;
  int qty;

  double get unitPrice => product.basePrice + variant.priceDelta;
  double get lineTotal => unitPrice * qty;
}

/// Product search + result list; taps add to the cart via [onAdd].
class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.onAdd});
  final void Function(Product, ProductVariant) onAdd;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final _searchCtl = TextEditingController();
  // The whole catalog loads once (server caps perPage at 500 — plenty), then
  // search + category filters run locally so typing filters instantly. The
  // old per-keystroke server search only ever saw the first 50 products.
  List<Product> _all = const [];
  String _query = '';
  String? _categoryId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res =
        await ref.read(catalogRepositoryProvider).merchantProducts(perPage: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      res.when(
        success: (page) =>
            _all = page.items.where((p) => p.isAvailable).toList(),
        failure: (_) {},
      );
    });
  }

  List<Product> get _results {
    final q = _query.trim().toLowerCase();
    return [
      for (final p in _all)
        if ((_categoryId == null || p.categoryId == _categoryId) &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
          p,
    ];
  }

  /// Unique categories present in the catalog, in first-seen order.
  List<Category> get _categories {
    final seen = <String>{};
    return [
      for (final p in _all)
        if (p.category != null && seen.add(p.category!.id)) p.category!,
    ];
  }

  Future<void> _pick(Product p) async {
    final variants = p.variants.where((v) => v.isAvailable).toList();
    if (variants.isEmpty) return;
    if (variants.length == 1) {
      widget.onAdd(p, variants.first);
      return;
    }
    final chosen = await showModalBottomSheet<ProductVariant>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final v in variants)
              ListTile(
                title: Text(v.label),
                trailing: Text(
                  '${_money.format(p.basePrice + v.priceDelta)} đ',
                ),
                onTap: () => Navigator.of(ctx).pop(v),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) widget.onAdd(p, chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm sản phẩm…',
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: BananSpacing.sm),
        if (_categories.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Tất cả'),
                    selected: _categoryId == null,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                ),
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(
                        () => _categoryId = _categoryId == c.id ? null : c.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
        ],
        if (_loading)
          const LinearProgressIndicator()
        else
          SizedBox(
            height: 220,
            child: _results.isEmpty
                ? const Center(child: Text('Không có sản phẩm.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${p.category?.name ?? "—"} · ${_money.format(p.basePrice)} đ',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => _pick(p),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

class _CartSection extends StatelessWidget {
  const _CartSection({required this.cart, required this.onChanged});
  final List<_CartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cart.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Text(
          'Chưa có món nào. Tìm và thêm sản phẩm ở trên.',
          style: TextStyle(color: theme.colorScheme.outline),
        ),
      );
    }
    final total = cart.fold<double>(0, (s, l) => s + l.lineTotal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in cart)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.product.name} (${line.variant.label})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () {
                  if (line.qty > 1) {
                    line.qty--;
                  } else {
                    cart.remove(line);
                  }
                  onChanged();
                },
              ),
              Text('${line.qty}'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () {
                  line.qty++;
                  onChanged();
                },
              ),
              SizedBox(
                width: 90,
                child: Text(
                  '${_money.format(line.lineTotal)} đ',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text('Tổng', style: theme.textTheme.titleMedium),
            ),
            Text(
              '${_money.format(total)} đ',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared schedule picker row (date + time → DateTime?).
class _SchedulePicker extends StatelessWidget {
  const _SchedulePicker({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == null
                ? 'Nhận: sớm nhất có thể'
                : 'Nhận: ${DateFormat('dd/MM HH:mm').format(value!)}',
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Chọn lịch'),
          onPressed: () async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 60)),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value ?? now),
            );
            if (time == null) return;
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          },
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

// ── Tạo đơn tại quầy ────────────────────────────────────────────────────────

class CounterOrderScreen extends ConsumerStatefulWidget {
  const CounterOrderScreen({super.key});

  @override
  ConsumerState<CounterOrderScreen> createState() => _CounterOrderScreenState();
}

class _CounterOrderScreenState extends ConsumerState<CounterOrderScreen> {
  final cart = <_CartLine>[];
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _scheduledFor;
  String? _storeId;
  List<Store> _stores = const [];
  bool _paid = true;
  bool _saving = false;
  // One key per screen visit: a double-tap or retry re-sends the SAME key and
  // the backend returns the first order instead of creating a duplicate.
  late String _requestKey;

  @override
  void initState() {
    super.initState();
    _requestKey = _newKey();
    if (_isAdmin) {
      Future.microtask(() async {
        final result = await ref.read(storesRepositoryProvider).listForAdmin();
        if (!mounted) return;
        result.when(
          success: (stores) => setState(() => _stores = stores),
          failure: (_) {},
        );
      });
    }
  }

  bool get _isAdmin =>
      ref.read(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

  String _newKey() =>
      'ctr-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addToCart(Product p, ProductVariant v) {
    final existing = cart.where(
      (l) => l.product.id == p.id && l.variant.id == v.id,
    );
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      cart.add(_CartLine(p, v, 1));
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (cart.isEmpty) {
      _snack('Thêm ít nhất một món.');
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().length < 7) {
      _snack('Điền tên và số điện thoại khách.');
      return;
    }
    if (_isAdmin && _storeId == null) {
      _snack('Admin cần chọn cửa hàng nhận đơn tại quầy.');
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(ordersApiProvider).createCounterOrder(
      items: [
        for (final l in cart)
          {
            'productId': l.product.id,
            'variantId': l.variant.id,
            'quantity': l.qty,
          },
      ],
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
      paidAtCounter: _paid,
      scheduledFor: _scheduledFor,
      notes: _notes.text.trim(),
      storeId: _storeId,
      clientRequestId: _requestKey,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (order) {
        _snack('Đã tạo ${order.code} và gửi bếp.');
        context.go('/orders/${order.id}');
      },
      failure: (f) => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MerchantShell(
      title: 'Tạo đơn tại quầy',
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          _ProductPicker(onAdd: _addToCart),
          const SizedBox(height: BananSpacing.md),
          Text('Giỏ hàng', style: theme.textTheme.titleMedium),
          _CartSection(cart: cart, onChanged: () => setState(() {})),
          const SizedBox(height: BananSpacing.lg),
          if (_isAdmin) ...[
            DropdownButtonFormField<String>(
              initialValue: _storeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cửa hàng nhận đơn'),
              items: [
                for (final store in _stores)
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
              ],
              onChanged: (value) => setState(() => _storeId = value),
            ),
            const SizedBox(height: BananSpacing.lg),
          ],
          Text('Khách hàng', style: theme.textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên khách'),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              helperText: 'Khách cũ sẽ được gộp lịch sử theo số này.',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (tuỳ chọn)'),
          ),
          const SizedBox(height: BananSpacing.md),
          _SchedulePicker(
            value: _scheduledFor,
            onChanged: (v) => setState(() => _scheduledFor = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đã thu tiền tại quầy'),
            subtitle: Text(
              _paid
                  ? 'Ghi nhận thanh toán tiền mặt (CASH)'
                  : 'Chưa thu, thu khi khách nhận bánh',
            ),
            value: _paid,
            onChanged: (v) => setState(() => _paid = v),
          ),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: BananSpacing.xl),
          PrimaryButton(
            label: 'Tạo & gửi bếp',
            icon: Icons.send_outlined,
            loading: _saving,
            expand: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Đặt hàng nội bộ ─────────────────────────────────────────────────────────

class InternalTransferScreen extends ConsumerStatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  ConsumerState<InternalTransferScreen> createState() =>
      _InternalTransferScreenState();
}

/// One kitchen-warehouse supply line in the transfer form.
class _SupplyLine {
  _SupplyLine(this.product) : qty = TextEditingController(text: '1');
  final MfgProduct product;
  final TextEditingController qty;
}

class _InternalTransferScreenState
    extends ConsumerState<InternalTransferScreen> {
  final cart = <_CartLine>[];
  final supplies = <_SupplyLine>[];
  List<MfgProduct> _mfgCatalog = const [];
  final _notes = TextEditingController();
  DateTime? _scheduledFor;
  String? _requestingStoreId; // admin only
  String? _destinationStoreId;
  List<Store> _stores = const [];
  bool _saving = false;
  late String _requestKey;

  bool get _isAdmin =>
      ref.read(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _requestKey =
        'itf-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}';
    // Store pickers: admin chooses the requesting store; everyone may pick a
    // different receiving branch.
    Future.microtask(() async {
      final repo = ref.read(storesRepositoryProvider);
      final res = _isAdmin ? await repo.listForAdmin() : await repo.list();
      if (!mounted) return;
      res.when(
        success: (stores) => setState(() => _stores = stores),
        failure: (_) {},
      );
    });
    // Kitchen-warehouse catalogue: what a branch can order besides cakes.
    Future.microtask(() async {
      final api = ref.read(manufacturingApiProvider);
      final raw = await api.listProducts(type: 'RAW');
      final pkg = await api.listProducts(type: 'PACKAGING');
      if (!mounted) return;
      setState(() {
        _mfgCatalog = [
          ...raw.when(success: (v) => v, failure: (_) => const <MfgProduct>[]),
          ...pkg.when(success: (v) => v, failure: (_) => const <MfgProduct>[]),
        ];
      });
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final s in supplies) {
      s.qty.dispose();
    }
    super.dispose();
  }

  void _addToCart(Product p, ProductVariant v) {
    final existing = cart.where(
      (l) => l.product.id == p.id && l.variant.id == v.id,
    );
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      cart.add(_CartLine(p, v, 1));
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (cart.isEmpty && supplies.isEmpty) {
      _snack('Thêm ít nhất một món hoặc một vật tư.');
      return;
    }
    final mfgItems = <Map<String, dynamic>>[];
    for (final s in supplies) {
      final qty = double.tryParse(s.qty.text.trim());
      if (qty == null || qty <= 0) {
        _snack('Nhập số lượng > 0 cho "${s.product.nameVi}".');
        return;
      }
      mfgItems.add({'mfgProductId': s.product.id, 'qty': qty});
    }
    if (_isAdmin && _requestingStoreId == null) {
      _snack('Admin cần chọn cửa hàng yêu cầu.');
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(ordersApiProvider).createInternalTransfer(
      items: [
        for (final l in cart)
          {
            'productId': l.product.id,
            'variantId': l.variant.id,
            'quantity': l.qty,
          },
      ],
      mfgItems: mfgItems,
      scheduledFor: _scheduledFor,
      notes: _notes.text.trim(),
      requestingStoreId: _requestingStoreId,
      destinationStoreId: _destinationStoreId,
      clientRequestId: _requestKey,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (order) {
        _snack('Đã tạo yêu cầu ${order.code} và gửi bếp.');
        context.go('/orders/${order.id}');
      },
      failure: (f) => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = _isAdmin;
    return MerchantShell(
      title: 'Đặt hàng nội bộ',
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          Text(
            'Bếp làm và giao về chi nhánh. Không phải đơn bán lẻ, '
            'không tính doanh thu.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: BananSpacing.md),
          _ProductPicker(onAdd: _addToCart),
          const SizedBox(height: BananSpacing.md),
          Text('Danh sách cần làm', style: theme.textTheme.titleMedium),
          _CartSection(cart: cart, onChanged: () => setState(() {})),
          const SizedBox(height: BananSpacing.lg),
          Text(
            'Vật tư từ kho bếp',
            style: theme.textTheme.titleMedium,
          ),
          Text(
            'Sữa, trái cây, ly, bao bì… bếp xuất kho và giao kèm.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: BananSpacing.sm),
          Autocomplete<MfgProduct>(
            // Rebuild after each pick so the field clears and the same list
            // can be searched again.
            key: ValueKey('supply-picker-${supplies.length}'),
            displayStringForOption: (p) => '${p.nameVi} (${p.code})',
            optionsBuilder: (t) {
              final q = t.text.trim().toLowerCase();
              final picked = supplies.map((s) => s.product.id).toSet();
              return _mfgCatalog.where(
                (p) =>
                    !picked.contains(p.id) &&
                    (q.isEmpty ||
                        p.nameVi.toLowerCase().contains(q) ||
                        p.code.toLowerCase().contains(q)),
              );
            },
            onSelected: (p) {
              if (supplies.any((s) => s.product.id == p.id)) return;
              setState(() => supplies.add(_SupplyLine(p)));
            },
            fieldViewBuilder: (context, ctl, focus, onSubmit) => TextField(
              controller: ctl,
              focusNode: focus,
              decoration: const InputDecoration(
                labelText: 'Thêm vật tư — gõ tên hoặc mã để tìm',
                prefixIcon: Icon(Icons.add_shopping_cart_outlined),
                isDense: true,
              ),
            ),
          ),
          for (final s in supplies)
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.product.nameVi,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: s.qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: s.product.uomCode,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() {
                    supplies.remove(s);
                    s.qty.dispose();
                  }),
                ),
              ],
            ),
          const SizedBox(height: BananSpacing.lg),
          if (isAdmin) ...[
            DropdownButtonFormField<String>(
              initialValue: _requestingStoreId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Cửa hàng yêu cầu (admin)'),
              items: [
                for (final s in _stores)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _requestingStoreId = v),
            ),
            const SizedBox(height: BananSpacing.sm),
          ],
          DropdownButtonFormField<String>(
            initialValue: _destinationStoreId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cửa hàng nhận hàng',
              helperText: 'Bỏ trống = chính cửa hàng yêu cầu.',
            ),
            items: [
              for (final s in _stores)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _destinationStoreId = v),
          ),
          const SizedBox(height: BananSpacing.md),
          _SchedulePicker(
            value: _scheduledFor,
            onChanged: (v) => setState(() => _scheduledFor = v),
          ),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: BananSpacing.xl),
          PrimaryButton(
            label: 'Tạo yêu cầu & gửi bếp',
            icon: Icons.send_outlined,
            loading: _saving,
            expand: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
