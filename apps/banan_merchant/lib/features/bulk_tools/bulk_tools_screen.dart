import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// All collections (merchant scope) — for the bulk-price "by collection"
/// selector. Returns (slug, name) pairs.
final _collectionsProvider =
    FutureProvider.autoDispose<List<MapEntry<String, String>>>((ref) async {
  final res = await ref.watch(collectionsApiProvider).store();
  return res.when(
    success: (list) =>
        list.map((c) => MapEntry(c.slug, c.name)).toList(),
    failure: (_) => const [],
  );
});

final _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

/// P4 #31/#32 — merchant bulk operations: bulk price adjustment + CSV import.
class BulkToolsScreen extends StatelessWidget {
  const BulkToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MerchantShell(
        title: 'Công cụ hàng loạt',
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(
                    text: 'Cập nhật giá',
                    icon: Icon(Icons.price_change_outlined),
                  ),
                  Tab(text: 'Nhập CSV', icon: Icon(Icons.upload_file_outlined)),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(children: [_BulkPriceTab(), _CsvImportTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulk price ─────────────────────────────────────────────────────────────

class _BulkPriceTab extends ConsumerStatefulWidget {
  const _BulkPriceTab();
  @override
  ConsumerState<_BulkPriceTab> createState() => _BulkPriceTabState();
}

class _BulkPriceTabState extends ConsumerState<_BulkPriceTab> {
  String _scope = 'all';
  String _mode = 'percent';
  final _amount = TextEditingController(text: '10');
  double _roundTo = 1000;
  String? _categoryId;
  String? _collectionSlug;
  bool _busy = false;
  BulkPriceResult? _preview;
  String? _msg;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run({required bool dryRun}) async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) {
      setState(() => _msg = 'Nhập số hợp lệ.');
      return;
    }
    if (_scope == 'category' && _categoryId == null) {
      setState(() => _msg = 'Chọn danh mục.');
      return;
    }
    if (_scope == 'collection' && _collectionSlug == null) {
      setState(() => _msg = 'Chọn bộ sưu tập.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final res = await ref.read(merchantToolsApiProvider).bulkPrice(
          scope: _scope,
          mode: _mode,
          amount: amount,
          categoryId: _scope == 'category' ? _categoryId : null,
          collectionSlug: _scope == 'collection' ? _collectionSlug : null,
          roundTo: _roundTo > 0 ? _roundTo : null,
          dryRun: dryRun,
        );
    if (!mounted) return;
    res.when(
      success: (r) => setState(() {
        _busy = false;
        _preview = r;
        _msg = dryRun
            ? 'Khớp ${r.matched} sản phẩm (xem trước).'
            : 'Đã cập nhật ${r.updated} sản phẩm.';
      }),
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final collections = ref.watch(_collectionsProvider);

    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Text('Điều chỉnh giá hàng loạt', style: theme.textTheme.titleLarge),
        const SizedBox(height: BananSpacing.xs),
        Text(
          'Tăng/giảm giá theo % hoặc số tiền cố định cho toàn bộ menu, một '
          'danh mục hoặc một bộ sưu tập. Luôn xem trước trước khi áp dụng.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: BananSpacing.lg),

        DropdownButtonFormField<String>(
          initialValue: _scope,
          decoration: const InputDecoration(labelText: 'Phạm vi'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tất cả sản phẩm')),
            DropdownMenuItem(value: 'category', child: Text('Theo danh mục')),
            DropdownMenuItem(
                value: 'collection', child: Text('Theo bộ sưu tập'),),
          ],
          onChanged: (v) => setState(() => _scope = v ?? 'all'),
        ),
        const SizedBox(height: BananSpacing.sm),
        if (_scope == 'category')
          categories.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải danh mục: $e'),
            data: (cats) => DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: [
                for (final Category c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
        if (_scope == 'collection')
          collections.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải bộ sưu tập: $e'),
            data: (cols) => DropdownButtonFormField<String>(
              initialValue: _collectionSlug,
              decoration: const InputDecoration(labelText: 'Bộ sưu tập'),
              items: [
                for (final c in cols)
                  DropdownMenuItem(value: c.key, child: Text(c.value)),
              ],
              onChanged: (v) => setState(() => _collectionSlug = v),
            ),
          ),
        const SizedBox(height: BananSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Kiểu'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Phần trăm %')),
                  DropdownMenuItem(value: 'fixed', child: Text('Số tiền (₫)')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'percent'),
              ),
            ),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: _mode == 'percent' ? 'Mức % (vd 10 / -10)' : 'Số ₫',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.sm),
        DropdownButtonFormField<double>(
          initialValue: _roundTo,
          decoration: const InputDecoration(labelText: 'Làm tròn'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Không làm tròn')),
            DropdownMenuItem(value: 1000, child: Text('Làm tròn 1.000₫')),
            DropdownMenuItem(value: 5000, child: Text('Làm tròn 5.000₫')),
          ],
          onChanged: (v) => setState(() => _roundTo = v ?? 0),
        ),
        const SizedBox(height: BananSpacing.lg),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(dryRun: true),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Xem trước'),
            ),
            const SizedBox(width: BananSpacing.sm),
            FilledButton.icon(
              onPressed: _busy ? null : _confirmApply,
              icon: const Icon(Icons.check),
              label: const Text('Áp dụng'),
            ),
          ],
        ),
        if (_msg != null) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(_msg!, style: theme.textTheme.bodyMedium),
        ],
        if (_preview != null && _preview!.sample.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.md),
          Text('Xem trước (tối đa 10 dòng):',
              style: theme.textTheme.titleSmall,),
          const SizedBox(height: BananSpacing.xs),
          for (final r in _preview!.sample)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(r.name)),
                  Text(
                    '${_fmt.format(r.from)} → ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  Text(_fmt.format(r.to),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmApply() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Áp dụng thay đổi giá?'),
        content: const Text(
          'Hành động này sẽ cập nhật giá thật của các sản phẩm khớp phạm vi. '
          'Bạn nên Xem trước trước. Tiếp tục?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Áp dụng'),),
        ],
      ),
    );
    if (ok ?? false) await _run(dryRun: false);
  }
}

// ── CSV import ───────────────────────────────────────────────────────────

class _CsvImportTab extends ConsumerStatefulWidget {
  const _CsvImportTab();
  @override
  ConsumerState<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends ConsumerState<_CsvImportTab> {
  final _csv = TextEditingController();
  bool _busy = false;
  String? _msg;
  BulkImportResult? _result;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  /// Minimal CSV parse: first line = header, comma-separated. Maps known
  /// columns (name, categoryName, basePrice, description, imageUrl).
  List<Map<String, dynamic>> _parse() {
    final lines = _csv.text
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final header = lines.first.split(',').map((h) => h.trim()).toList();
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final cells = line.split(',');
      final row = <String, dynamic>{};
      for (var i = 0; i < header.length && i < cells.length; i++) {
        final key = header[i];
        final val = cells[i].trim();
        if (val.isEmpty) continue;
        if (key == 'basePrice') {
          row[key] = double.tryParse(val) ?? 0;
        } else {
          row[key] = val;
        }
      }
      if ((row['name'] as String?)?.isNotEmpty ?? false) rows.add(row);
    }
    return rows;
  }

  Future<void> _import() async {
    final rows = _parse();
    if (rows.isEmpty) {
      setState(() => _msg = 'Không tìm thấy dòng hợp lệ. Kiểm tra header.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
      _result = null;
    });
    final res = await ref.read(merchantToolsApiProvider).bulkImport(rows);
    if (!mounted) return;
    res.when(
      success: (r) => setState(() {
        _busy = false;
        _result = r;
        _msg = 'Tạo mới ${r.created}, bỏ qua ${r.skipped}, lỗi ${r.errors.length}.';
        // Refresh the merchant menu so new products show up.
        ref.invalidate(categoriesProvider);
      }),
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _parse();
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Text('Nhập sản phẩm từ CSV', style: theme.textTheme.titleLarge),
        const SizedBox(height: BananSpacing.xs),
        Text(
          'Dán nội dung CSV. Dòng đầu là tiêu đề cột. Cột hỗ trợ: '
          'name, categoryName, basePrice, description, imageUrl. '
          'Sản phẩm trùng slug sẽ được bỏ qua (an toàn khi chạy lại).',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: BananSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            _csv.text =
                'name,categoryName,basePrice,description\n'
                'Bánh Test A,Classic Cake,95000,Mô tả ngắn\n'
                'Bánh Test B,Classic Cake,120000,';
            setState(() {});
          },
          icon: const Icon(Icons.article_outlined),
          label: const Text('Chèn mẫu'),
        ),
        const SizedBox(height: BananSpacing.sm),
        TextField(
          controller: _csv,
          minLines: 6,
          maxLines: 16,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'name,categoryName,basePrice,description\n…',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: BananSpacing.sm),
        Text('Đã nhận diện ${preview.length} dòng.',
            style: theme.textTheme.bodySmall,),
        const SizedBox(height: BananSpacing.md),
        FilledButton.icon(
          onPressed: _busy || preview.isEmpty ? null : _import,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),)
              : const Icon(Icons.upload_outlined),
          label: Text(_busy ? 'Đang nhập…' : 'Nhập ${preview.length} sản phẩm'),
        ),
        if (_msg != null) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(_msg!, style: theme.textTheme.titleSmall),
        ],
        if (_result != null && _result!.errors.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.sm),
          Text('Lỗi:', style: theme.textTheme.titleSmall),
          for (final e in _result!.errors)
            Text('• Dòng ${e.row} (${e.name}): ${e.error}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),),
        ],
      ],
    );
  }
}
