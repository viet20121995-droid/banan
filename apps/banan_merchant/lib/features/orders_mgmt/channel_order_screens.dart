import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart'
    show WardPickerField;
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

  /// Cake name tag / message piped ("Happy Birthday Mẹ") — the kitchen
  /// reads it on the order row.
  String customMessage = '';

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
    final res = await ref
        .read(catalogRepositoryProvider)
        .merchantProducts(perPage: 500);
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
        for (final line in cart) ...[
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
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: TextFormField(
              key: ValueKey('tag-${line.product.id}-${line.variant.id}'),
              initialValue: line.customMessage,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Name tag / lời nhắn trên bánh (tuỳ chọn)',
                isDense: true,
                counterText: '',
              ),
              onChanged: (v) => line.customMessage = v,
            ),
          ),
        ],
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
  final _addressLine = TextEditingController();
  final _deliveryFee = TextEditingController();
  String? _wardCode;
  DateTime? _scheduledFor;
  String? _storeId;
  List<Store> _stores = const [];
  bool _paid = true;
  bool _delivery = false;
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
    _addressLine.dispose();
    _deliveryFee.dispose();
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
    final fee =
        int.tryParse(_deliveryFee.text.replaceAll(RegExp('[^0-9]'), ''));
    if (_delivery && _addressLine.text.trim().isEmpty) {
      _snack('Đơn giao hàng cần địa chỉ giao.');
      return;
    }
    if (_delivery && _wardCode == null) {
      _snack('Chọn phường/xã (địa giới mới) cho địa chỉ giao.');
      return;
    }
    if (_delivery && (fee == null || fee < 0)) {
      _snack('Nhập phí giao hàng (0 nếu miễn phí).');
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
            if (l.customMessage.trim().isNotEmpty)
              'customMessage': l.customMessage.trim(),
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
      deliveryAddress: _delivery
          ? {
              'recipient': _name.text.trim(),
              'phone': _phone.text.trim(),
              'line1': _addressLine.text.trim(),
              'wardCode': _wardCode,
              'city': 'TP. Hồ Chí Minh',
            }
          : null,
      deliveryFeeVnd: _delivery ? fee : null,
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
          // Phone/Zalo orders the shop delivers itself.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giao hàng tận nơi'),
            subtitle: Text(
              _delivery
                  ? 'Shipper giao theo địa chỉ dưới đây'
                  : 'Khách đến lấy tại quầy',
            ),
            value: _delivery,
            onChanged: (v) => setState(() => _delivery = v),
          ),
          if (_delivery) ...[
            TextField(
              controller: _addressLine,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ giao (số nhà, đường, khu phố)',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            // Post-2025 ward catalog only — no district, no free-text area.
            WardPickerField(
              selectedCode: _wardCode,
              onChanged: (code) => setState(() => _wardCode = code),
              helperText: 'Phường/xã theo địa giới mới từ 01/07/2025.',
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _deliveryFee,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Phí giao hàng (đ)',
                helperText:
                    'Nhân viên tự chốt với khách — không áp bảng phí website. Cộng vào tổng đơn.',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
          ],
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

/// Branch order sheet, laid out like the paper/Excel order book the branches
/// already fill in: every orderable line listed under its section (bánh,
/// nguyên liệu pha chế, bao bì, vật tư khác) with a quantity cell — staff
/// scan down and type numbers instead of searching item by item.
class InternalTransferScreen extends ConsumerStatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  ConsumerState<InternalTransferScreen> createState() =>
      _InternalTransferScreenState();
}

enum _Section { cake, drink, packaging, other }

/// One line of the sheet: a menu variant or a warehouse item.
class _SheetRow {
  _SheetRow.menu(this.product, this.variant)
      : mfg = null,
        section = _Section.cake,
        unit = 'cái';

  _SheetRow.mfg(MfgProduct this.mfg, this.section)
      : product = null,
        variant = null,
        unit = mfg.uomCode;

  final Product? product;
  final ProductVariant? variant;
  final MfgProduct? mfg;
  final _Section section;
  final String unit;
  final qty = TextEditingController();

  String get code => mfg?.code ?? variant?.sku ?? '';

  /// Sub-heading the row sits under (Excel "Phân loại"): menu category or
  /// warehouse category.
  String get group =>
      mfg != null ? mfg!.categoryName : (product!.category?.name ?? 'Khác');

  /// Macaron (single) × 9 flavours reads "Macaron (single) — Lemon"; a 16cm
  /// cake reads "Name — 16cm"; single-variant products are just the name.
  String get name {
    if (mfg != null) return mfg!.nameVi;
    final p = product!;
    if (p.variants.length <= 1) return p.name;
    final v = variant!;
    final parts = [
      if (!const {'Default', 'Single'}.contains(v.size)) v.size,
      if (!const {'Default', 'Classic'}.contains(v.flavor) &&
          v.flavor != p.name)
        v.flavor,
    ];
    return parts.isEmpty ? p.name : '${p.name} — ${parts.join(' ')}';
  }

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;

  bool matches(String q) =>
      q.isEmpty ||
      name.toLowerCase().contains(q) ||
      code.toLowerCase().contains(q) ||
      group.toLowerCase().contains(q);
}

class _InternalTransferScreenState
    extends ConsumerState<InternalTransferScreen> {
  List<_SheetRow> _rows = const [];
  bool _loading = true;
  String _filter = '';
  // Packaging / other supplies are long lists — folded until needed.
  final _open = <_Section>{_Section.cake, _Section.drink};
  final _notes = TextEditingController();
  DateTime? _scheduledFor;
  String? _requestingStoreId; // admin only
  String? _destinationStoreId;
  List<Store> _stores = const [];
  bool _saving = false;
  late String _requestKey;

  bool get _isAdmin =>
      ref.read(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

  /// Bar restock is keyed on Sunday and Thursday only (the backend enforces
  /// the same rule on the Vietnam calendar; this just greys the cells).
  bool get _drinkOrderDay => const {DateTime.sunday, DateTime.thursday}
      .contains(DateTime.now().weekday);

  @override
  void initState() {
    super.initState();
    _requestKey =
        'itf-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}';
    Future.microtask(() async {
      final repo = ref.read(storesRepositoryProvider);
      final res = _isAdmin ? await repo.listForAdmin() : await repo.list();
      if (!mounted) return;
      res.when(
        success: (stores) => setState(() => _stores = stores),
        failure: (_) {},
      );
    });
    Future.microtask(_loadSheet);
  }

  Future<void> _loadSheet() async {
    final catalog = await ref
        .read(catalogRepositoryProvider)
        .merchantProducts(perPage: 500);
    final api = ref.read(manufacturingApiProvider);
    final bar = await api.listProducts(drinkIngredient: true);
    final pkg = await api.listProducts(type: 'PACKAGING');
    final raw = await api.listProducts(type: 'RAW');
    if (!mounted) return;
    final drinks = bar.when(
      success: (v) => v,
      failure: (_) => const <MfgProduct>[],
    );
    final packaging = pkg.when(
      success: (v) => v,
      failure: (_) => const <MfgProduct>[],
    );
    final others = raw.when(
      success: (v) => v,
      failure: (_) => const <MfgProduct>[],
    );
    final drinkIds = drinks.map((p) => p.id).toSet();
    // Counter drinks are mixed at the bar, not ordered from the kitchen.
    final products = catalog
        .when(success: (page) => page.items, failure: (_) => const <Product>[])
        .where((p) => p.category?.slug != 'drink-collection')
        .toList()
      ..sort((a, b) {
        final c = (a.category?.sortOrder ?? 999)
            .compareTo(b.category?.sortOrder ?? 999);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    setState(() {
      _rows = [
        for (final p in products)
          for (final v in p.variants) _SheetRow.menu(p, v),
        for (final m in drinks) _SheetRow.mfg(m, _Section.drink),
        for (final m in packaging)
          if (!drinkIds.contains(m.id)) _SheetRow.mfg(m, _Section.packaging),
        for (final m in others)
          if (!drinkIds.contains(m.id)) _SheetRow.mfg(m, _Section.other),
      ];
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.qty.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  List<_SheetRow> get _picked => [
        for (final r in _rows)
          if (r.quantity > 0) r,
      ];

  Future<void> _submit() async {
    final picked = _picked;
    if (picked.isEmpty) {
      _snack('Điền số lượng cho ít nhất một dòng.');
      return;
    }
    final items = <Map<String, dynamic>>[];
    final mfgItems = <Map<String, dynamic>>[];
    for (final r in picked) {
      if (r.mfg != null) {
        mfgItems.add({'mfgProductId': r.mfg!.id, 'qty': r.quantity});
        continue;
      }
      if (r.quantity != r.quantity.roundToDouble()) {
        _snack('"${r.name}": bánh đặt theo cái, nhập số nguyên.');
        return;
      }
      items.add({
        'productId': r.product!.id,
        'variantId': r.variant!.id,
        'quantity': r.quantity.round(),
      });
    }
    if (_isAdmin && _requestingStoreId == null) {
      _snack('Admin cần chọn cửa hàng yêu cầu.');
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(ordersApiProvider).createInternalTransfer(
          items: items,
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

  static const _titles = {
    _Section.cake: 'BÁNH / CAKE',
    _Section.drink: 'NGUYÊN LIỆU PHA CHẾ / DRINK INGREDIENTS',
    _Section.packaging: 'VẬT TƯ ĐÓNG GÓI / PACKAGING',
    _Section.other: 'VẬT TƯ KHÁC TỪ KHO',
  };

  String _hint(_Section s) => switch (s) {
        _Section.cake => 'Đặt hôm nay, bếp giao sáng hôm sau.',
        _Section.drink => _drinkOrderDay
            ? 'Đặt Chủ nhật và Thứ 5, giao sáng hôm sau — hôm nay đặt được.'
            : 'Chỉ đặt Chủ nhật và Thứ 5 (giao sáng hôm sau). Hôm nay không đặt được.',
        _Section.packaging => 'Ly, hộp, túi… bếp xuất kho giao kèm.',
        _Section.other => 'Nguyên liệu kho khác, dùng khi cần.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = _isAdmin;
    final q = _filter.trim().toLowerCase();
    final picked = _picked;
    final pickedQty = picked.fold<double>(0, (a, r) => a + r.quantity);
    return MerchantShell(
      title: 'Đặt hàng nội bộ',
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          Text(
            'Phiếu đặt hàng chi nhánh → bếp. Điền số lượng vào cột SL, để '
            'trống dòng không đặt. Không phải đơn bán lẻ, không tính doanh thu.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: BananSpacing.md),
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
          const SizedBox(height: BananSpacing.md),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tìm nhanh trong phiếu — tên, mã, nhóm',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: BananSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(BananSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final section in _Section.values)
              ..._sectionWidgets(section, q, theme),
          const SizedBox(height: BananSpacing.lg),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: BananSpacing.md),
          Text(
            picked.isEmpty
                ? 'Chưa điền dòng nào.'
                : '${picked.length} dòng · tổng ${_fmtQty(pickedQty)}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: BananSpacing.sm),
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

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  List<Widget> _sectionWidgets(_Section section, String q, ThemeData theme) {
    final rows = [
      for (final r in _rows)
        if (r.section == section && r.matches(q)) r,
    ];
    if (rows.isEmpty) return const [];
    // A search always opens the section it matched in.
    final open = q.isNotEmpty || _open.contains(section);
    final enabled = section != _Section.drink || _drinkOrderDay;
    final pickedHere = rows.where((r) => r.quantity > 0).length;
    return [
      InkWell(
        onTap: () => setState(() {
          if (!_open.add(section)) _open.remove(section);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BananSpacing.md,
            vertical: BananSpacing.sm,
          ),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18),
              const SizedBox(width: BananSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_titles[section]}  ·  ${rows.length} dòng'
                      '${pickedHere > 0 ? '  ·  đã điền $pickedHere' : ''}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _hint(section),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.outline
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (open) ...[
        _SheetHeader(theme: theme),
        for (var i = 0; i < rows.length; i++) ...[
          if (i == 0 || rows[i].group != rows[i - 1].group)
            Padding(
              padding: const EdgeInsets.only(
                left: BananSpacing.md,
                top: BananSpacing.sm,
                bottom: 2,
              ),
              child: Text(
                rows[i].group,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          _SheetLine(
            index: i + 1,
            row: rows[i],
            enabled: enabled,
            onChanged: () => setState(() {}),
          ),
        ],
      ],
      const SizedBox(height: BananSpacing.md),
    ];
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style =
        theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BananSpacing.md,
        BananSpacing.xs,
        BananSpacing.md,
        0,
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('STT', style: style)),
          Expanded(child: Text('Tên sản phẩm', style: style)),
          SizedBox(width: 48, child: Text('ĐVT', style: style)),
          SizedBox(
            width: 84,
            child: Text('SL', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine({
    required this.index,
    required this.row,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final _SheetRow row;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = row.quantity > 0;
    return Container(
      color: picked
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$index', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, overflow: TextOverflow.ellipsis),
                if (row.code.isNotEmpty)
                  Text(
                    row.code,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(row.unit, style: theme.textTheme.bodySmall),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              controller: row.qty,
              enabled: enabled,
              keyboardType: TextInputType.numberWithOptions(
                decimal: row.mfg != null,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '–',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
