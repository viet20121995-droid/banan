import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/file_download.dart';

/// The branch order book as the kitchen works it. One sheet per delivery
/// day: a row per item, per branch the quantity asked ("Đặt") next to an
/// editable "Giao", totals and the shortfall on the right. Save writes the
/// edits back onto the orders, "Xuất đi cả ngày" dispatches every order of
/// the day, "Xuất PDF" prints the sheet.
class TransferSummaryScreen extends ConsumerStatefulWidget {
  const TransferSummaryScreen({super.key, this.initialDay});

  /// `yyyy-MM-dd` (VN calendar) to open on — from the board's row tap.
  final String? initialDay;

  @override
  ConsumerState<TransferSummaryScreen> createState() => _TransferSummaryScreenState();
}

class _TransferSummaryScreenState extends ConsumerState<TransferSummaryScreen> {
  static final _fmt = NumberFormat('#,##0.###', 'vi');

  TransferSheetDto? _sheet;
  String? _day;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  // One controller per cell, keyed "rowKey|storeId"; rebuilt on every fetch.
  final _ctl = <String, TextEditingController>{};
  Listenable _cells = Listenable.merge(const []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _q(double v) => v == 0 ? '' : _fmt.format(v);

  static String _vnToday() {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateFormat('yyyy-MM-dd').format(vn);
  }

  static String _cellKey(String rowKey, String storeId) => '$rowKey|$storeId';

  TransferSheetDayDto? get _current {
    final sheet = _sheet;
    if (sheet == null) return null;
    for (final d in sheet.days) {
      if (d.day == _day) return d;
    }
    return null;
  }

  Future<void> _load({String? keepDay}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ref.read(ordersApiProvider).transferSheet();
    if (!mounted) return;
    res.when(
      success: (sheet) {
        final days = sheet.days.map((d) => d.day).toList();
        final wanted = keepDay ?? _day ?? widget.initialDay;
        final today = _vnToday();
        final day = days.contains(wanted)
            ? wanted
            : days.where((d) => d.compareTo(today) >= 0).firstOrNull ?? days.lastOrNull;
        for (final c in _ctl.values) {
          c.dispose();
        }
        _ctl.clear();
        for (final d in sheet.days) {
          for (final r in d.rows) {
            for (final s in d.stores) {
              final cell = r.byStore[s.id];
              if (cell == null) continue;
              _ctl[_cellKey(r.key, s.id)] = TextEditingController(text: _q(cell.shipped));
            }
          }
        }
        setState(() {
          _sheet = sheet;
          _day = day;
          _cells = Listenable.merge(_ctl.values.toList());
          _loading = false;
        });
      },
      failure: (f) => setState(() {
        _error = f.message ?? f.code;
        _loading = false;
      }),
    );
  }

  double _typed(String rowKey, String storeId, double fallback) {
    final t = _ctl[_cellKey(rowKey, storeId)]?.text.trim().replaceAll(',', '.');
    if (t == null) return fallback;
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? fallback;
  }

  /// Cells whose typed value differs from what the orders currently carry.
  List<({TransferSheetRowDto row, String storeId, double qty})> _dirty(
    TransferSheetDayDto day,
  ) =>
      [
        for (final r in day.rows)
          for (final s in day.stores)
            if (r.byStore[s.id] case final cell?)
              if (_typed(r.key, s.id, cell.shipped) != cell.shipped)
                (row: r, storeId: s.id, qty: _typed(r.key, s.id, cell.shipped)),
      ];

  Future<void> _save() async {
    final day = _current;
    if (day == null) return;
    final lines = <Map<String, dynamic>>[];
    for (final d in _dirty(day)) {
      final cell = d.row.byStore[d.storeId]!;
      // A branch may have two orders behind one cell: fill the lines in
      // order up to what each asked for, the last one takes the rest.
      var remaining = d.qty;
      for (var i = 0; i < cell.lines.length; i++) {
        final l = cell.lines[i];
        final take =
            i == cell.lines.length - 1 ? remaining : remaining.clamp(0, l.ordered).toDouble();
        remaining -= take;
        if (take != l.shipped) {
          lines.add({
            'orderId': l.orderId,
            'itemId': l.itemId,
            'kind': l.kind,
            'qty': l.kind == 'item' ? take.round() : take,
          });
        }
      }
    }
    if (lines.isEmpty) return;
    setState(() => _busy = true);
    final res = await ref.read(ordersApiProvider).saveTransferSheet(lines);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (n) {
        _snack('Đã lưu số giao cho $n phiếu.');
        _load();
      },
      failure: (f) => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  Future<void> _dispatchDay() async {
    final day = _current;
    if (day == null) return;
    if (_dirty(day).isNotEmpty) {
      _snack('Lưu số giao trước khi xuất.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xuất đi cả ngày?'),
        content: Text(
          '${day.orders.length} phiếu giao ${_dayLabel(day.day)} sẽ chuyển '
          'sang "Đã xuất" và hoàn tất. Chi nhánh không cần xác nhận thêm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Chưa'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xuất đi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await ref.read(ordersApiProvider).dispatchTransferDay(day.day);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (r) {
        final failed = r.failed.isEmpty
            ? ''
            : ' Không xuất được: ${r.failed.map((f) => '${f.code} (${f.message})').join('; ')}.';
        _snack('Đã xuất ${r.dispatched.length} phiếu.$failed');
        _load();
      },
      failure: (f) => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  Future<void> _pdf() async {
    final day = _current;
    if (day == null) return;
    setState(() => _busy = true);
    final res = await ref.read(ordersApiProvider).transferSheetPdf(day.day);
    if (!mounted) return;
    setState(() => _busy = false);
    await res.when(
      success: (bytes) => openOrSaveFile(
        bytes,
        'phieu-dat-hang-${day.day}.pdf',
        'application/pdf',
      ),
      failure: (f) async => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static String _dayLabel(String day) {
    final d = DateTime.parse(day);
    return '${_weekdays[d.weekday - 1]} ${DateFormat('dd/MM').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt hàng nội bộ'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Lỗi: $_error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : _body(theme),
    );
  }

  Widget _body(ThemeData theme) {
    final sheet = _sheet!;
    final day = _current;
    if (sheet.days.isEmpty || day == null) {
      return const EmptyState(
        title: 'Không có đơn nội bộ nào chờ giao',
        message: 'Khi chi nhánh đặt hàng, phiếu tổng theo ngày giao hiện ở đây.',
        icon: Icons.table_chart_outlined,
      );
    }
    final today = _vnToday();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final d in sheet.days)
                ChoiceChip(
                  label: Text(
                    '${_dayLabel(d.day)}'
                    '${d.day == today ? ' · hôm nay' : ''}'
                    ' · ${d.orders.length} phiếu',
                  ),
                  selected: d.day == _day,
                  onSelected: (_) => setState(() => _day = d.day),
                ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          Text(
            'Giao ${_dayLabel(day.day)} · ${day.orders.map((o) => o.code).join(', ')}. '
            'Cột "Giao" sửa được; số giao nhỏ hơn số đặt tô đỏ.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: BananSpacing.md),
          _SheetTable(
            day: day,
            controllers: _ctl,
            cells: _cells,
            typed: _typed,
            cellKey: _cellKey,
            fmt: _q,
          ),
          const SizedBox(height: BananSpacing.lg),
          ListenableBuilder(
            listenable: _cells,
            builder: (_, __) {
              final dirty = _dirty(day).length;
              return Wrap(
                spacing: BananSpacing.md,
                runSpacing: BananSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || dirty == 0 ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      dirty == 0 ? 'Lưu số giao' : 'Lưu $dirty ô đã sửa',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Xuất PDF'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy || dirty > 0 ? null : _dispatchDay,
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Xuất đi cả ngày'),
                  ),
                  if (dirty > 0)
                    Text(
                      'Lưu trước khi xuất.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: BananSpacing.lg),
          Text('Phiếu trong ngày', style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.xs),
          for (final o in day.orders)
            Text(
              '${o.code} · ${day.stores.where((s) => s.id == o.storeId).map((s) => _SheetTable.shortStore(s.name)).firstOrNull ?? ''}'
              ' · ${_stageLabel(o.kitchenStatus)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static String _stageLabel(String? kitchenStatus) => switch (kitchenStatus) {
        'PREPARING' => 'đang làm',
        'READY_DISPATCH' => 'sẵn sàng giao',
        _ => 'chờ nhận',
      };
}

class _SheetTable extends StatelessWidget {
  const _SheetTable({
    required this.day,
    required this.controllers,
    required this.cells,
    required this.typed,
    required this.cellKey,
    required this.fmt,
  });

  final TransferSheetDayDto day;
  final Map<String, TextEditingController> controllers;
  final Listenable cells;
  final double Function(String rowKey, String storeId, double fallback) typed;
  final String Function(String rowKey, String storeId) cellKey;
  final String Function(double) fmt;

  /// "Banan – Lê Thánh Tôn" → "Lê Thánh Tôn": every column is a Banan branch.
  static String shortStore(String name) => name.replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? Colors.black12;
    final stores = day.stores;
    Widget cell(Widget child, {bool head = false, Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: DefaultTextStyle.merge(
            style: head
                ? theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium,
            child: child,
          ),
        );
    Widget num(String v, {bool bold = false, Color? color}) => cell(
          Text(
            v.isEmpty ? '—' : v,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : null,
              color: v.isEmpty ? theme.colorScheme.outline : color,
            ),
          ),
        );

    final sections = <(String, List<TransferSheetRowDto>)>[
      ('BÁNH / CAKE', day.rows.where((r) => !r.isSupply).toList()),
      ('NGUYÊN LIỆU PHA CHẾ', day.rows.where((r) => r.isSupply && r.isDrinkIngredient).toList()),
      ('BAO BÌ & VẬT TƯ', day.rows.where((r) => r.isSupply && !r.isDrinkIngredient).toList()),
    ];
    final colCount = 2 + stores.length * 2 + 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = 220.0 + 40 + stores.length * 130 + 3 * 70;
        final table = ListenableBuilder(
          listenable: cells,
          builder: (_, __) => Table(
            columnWidths: {
              0: const FlexColumnWidth(3.2),
              1: const FixedColumnWidth(44),
              for (var i = 0; i < stores.length; i++) ...{
                2 + i * 2: const FlexColumnWidth(0.8),
                3 + i * 2: const FlexColumnWidth(1),
              },
              colCount - 3: const FlexColumnWidth(0.9),
              colCount - 2: const FlexColumnWidth(0.9),
              colCount - 1: const FlexColumnWidth(0.8),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(horizontalInside: BorderSide(color: border)),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                children: [
                  cell(const Text('Tên sản phẩm'), head: true),
                  cell(const Text('ĐVT'), head: true),
                  for (final s in stores) ...[
                    cell(
                      Text(
                        shortStore(s.name),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                      head: true,
                    ),
                    cell(const SizedBox.shrink(), head: true),
                  ],
                  cell(
                    const Text('Tổng đặt', textAlign: TextAlign.end),
                    head: true,
                  ),
                  cell(
                    const Text('Tổng giao', textAlign: TextAlign.end),
                    head: true,
                  ),
                  cell(
                    Text(
                      'Thiếu',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    head: true,
                  ),
                ],
              ),
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                ),
                children: [
                  cell(const SizedBox.shrink()),
                  cell(const SizedBox.shrink()),
                  for (final _ in stores) ...[
                    cell(
                      Text(
                        'Đặt',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    cell(
                      Text(
                        'Giao',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  cell(const SizedBox.shrink()),
                  cell(const SizedBox.shrink()),
                  cell(const SizedBox.shrink()),
                ],
              ),
              for (final (title, rows) in sections)
                if (rows.isNotEmpty) ...[
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    ),
                    children: [
                      cell(
                        Text(
                          title,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (var i = 1; i < colCount; i++) cell(const SizedBox.shrink()),
                    ],
                  ),
                  for (final r in rows) _row(r, theme, cell, num),
                ],
            ],
          ),
        );
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }

  TableRow _row(
    TransferSheetRowDto r,
    ThemeData theme,
    Widget Function(Widget, {bool head, Color? bg}) cell,
    Widget Function(String, {bool bold, Color? color}) num,
  ) {
    var ordered = 0.0;
    var shipped = 0.0;
    final storeCells = <Widget>[];
    for (final s in day.stores) {
      final c = r.byStore[s.id];
      if (c == null) {
        storeCells
          ..add(num(''))
          ..add(num(''));
        continue;
      }
      final v = typed(r.key, s.id, c.shipped);
      ordered += c.ordered;
      shipped += v;
      final short = v < c.ordered;
      final edited = v != c.shipped;
      storeCells
        ..add(num(fmt(c.ordered)))
        ..add(
          cell(
            TextField(
              controller: controllers[cellKey(r.key, s.id)],
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: short ? theme.colorScheme.error : null,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: edited ? const Color(0xFFFFF3C4) : theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
            ),
          ),
        );
    }
    final short = ordered - shipped;
    return TableRow(
      children: [
        cell(
          Row(
            children: [
              if (r.isSupply) ...[
                Icon(
                  r.isDrinkIngredient ? Icons.local_cafe_outlined : Icons.inventory_2_outlined,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(r.label, softWrap: true)),
            ],
          ),
        ),
        cell(Text(r.unit, style: theme.textTheme.bodySmall)),
        ...storeCells,
        num(fmt(ordered)),
        num(fmt(shipped), bold: true),
        num(
          short > 0 ? '-${fmt(short)}' : '',
          bold: true,
          color: theme.colorScheme.error,
        ),
      ],
    );
  }
}
