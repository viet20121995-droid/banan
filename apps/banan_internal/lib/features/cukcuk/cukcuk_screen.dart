import 'dart:async';
import 'dart:convert';

import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/cukcuk_models.dart';
import '../../data/internal_api.dart';
import '../../shared/internal_shell.dart';
import '../../shared/widgets.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

/// One table column of a dataset: header + which raw-row keys feed it.
class _Col {
  const _Col(this.header, this.keys, {this.money = false, this.date = false});
  final String header;
  final List<String> keys;
  final bool money;
  final bool date;
}

/// Columns per dataset. Keys are candidates (first non-empty wins) because
/// CukCuk names the same thing differently across endpoints; the full raw
/// row is always one tap away.
const _columns = <String, List<_Col>>{
  'branches': [
    _Col('Mã', ['Code']),
    _Col('Tên', ['Name']),
    _Col('Địa chỉ', ['Address']),
    _Col('Điện thoại', ['Tel', 'Phone']),
    _Col('Ngừng', ['Inactive']),
  ],
  'categories': [
    _Col('Mã', ['Code']),
    _Col('Tên nhóm', ['Name']),
    _Col('Mô tả', ['Description']),
    _Col('Ngừng', ['Inactive']),
  ],
  'items': [
    _Col('Mã', ['Code']),
    _Col('Tên món', ['Name']),
    _Col('Nhóm', ['CategoryName']),
    _Col('ĐVT', ['UnitName']),
    _Col('Giá', ['Price', 'UnitPrice'], money: true),
    _Col('Ngừng', ['Inactive']),
  ],
  'customers': [
    _Col('Mã', ['Code']),
    _Col('Tên', ['Name']),
    _Col('SĐT', ['Tel', 'Phone']),
    _Col('Email', ['Email']),
    _Col('Sinh nhật', ['Birthday'], date: true),
    _Col('Hạng', ['MemberLevelName', 'MembershipLevelName']),
    _Col('Thẻ', ['MemberCardNo']),
    _Col('Điểm', ['TotalPoint', 'Point', 'AvailablePoint']),
    _Col('Tổng chi', ['TotalAmount'], money: true),
  ],
  'invoices': [
    _Col('Số HĐ', ['RefNo']),
    _Col('Ngày', ['RefDate'], date: true),
    _Col('Chi nhánh', ['BranchName']),
    _Col('Khách', ['CustomerName']),
    _Col('SĐT', ['CustomerTel']),
    _Col('Giảm', ['DiscountAmount'], money: true),
    _Col('Tổng', ['TotalAmount', 'Amount'], money: true),
    _Col('Thanh toán', ['PaymentStatus']),
  ],
  'orders': [
    _Col('Số', ['No', 'Code']),
    _Col('Ngày', ['Date', 'CreatedDate'], date: true),
    _Col('Chi nhánh', ['BranchName']),
    _Col('Bàn', ['TableName']),
    _Col('Khách', ['CustomerName']),
    _Col('Tổng', ['TotalAmount', 'Amount'], money: true),
    _Col('Trạng thái', ['Status']),
  ],
};

/// "Update dữ liệu CukCuk": sync status per dataset, one-tap sync, and a
/// searchable table of every dataset with the raw row on tap.
class CukcukScreen extends ConsumerStatefulWidget {
  const CukcukScreen({super.key});

  @override
  ConsumerState<CukcukScreen> createState() => _CukcukScreenState();
}

class _CukcukScreenState extends ConsumerState<CukcukScreen> {
  Result<CukcukStatus, AppFailure>? _status;
  String _kind = 'customers';
  String _q = '';
  int _page = 1;
  Result<CukcukPage, AppFailure>? _records;
  bool _busy = false;
  Timer? _poll;
  final _search = TextEditingController();

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadRecords();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final res = await _api.cukcukStatus();
    if (!mounted) return;
    setState(() => _status = res);
    final running = res.valueOrNull?.kinds.any((k) => k.running) ?? false;
    if (running && _poll == null) {
      // A sync is in flight: refresh the counters every few seconds until
      // every dataset is idle, then reload the table once.
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _loadStatus());
    } else if (!running && _poll != null) {
      _poll!.cancel();
      _poll = null;
      setState(() => _busy = false);
      _loadRecords();
    }
  }

  Future<void> _loadRecords() async {
    setState(() => _records = null);
    final res = await _api.cukcukRecords(kind: _kind, q: _q, page: _page);
    if (mounted) setState(() => _records = res);
  }

  void _pickKind(String kind) {
    setState(() {
      _kind = kind;
      _page = 1;
    });
    _loadRecords();
  }

  Future<void> _sync(String kind) async {
    setState(() => _busy = true);
    final res = await _api.cukcukSync(kind);
    if (!mounted) return;
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang đồng bộ trên server, số liệu tự cập nhật.')),
        );
        _loadStatus();
      },
      failure: (f) {
        setState(() => _busy = false);
        showFailure(context, f);
      },
    );
  }

  Future<void> _applyCustomers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật khách lên website'),
        content: const Text(
          'Khớp khách CukCuk với tài khoản web theo số điện thoại và điền tên, '
          'sinh nhật, giới tính, email còn thiếu. Không đổi điểm / hạng thành viên '
          'trên web.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Cập nhật')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await _api.cukcukApplyCustomers();
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (r) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khớp ${r.matched} tài khoản, cập nhật ${r.updated}.')),
      ),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _openRecord(CukcukRecord r) async {
    // Invoices lazily fetch their lines on first open.
    final full = r.kind == 'invoices' && r.data['__detail'] == null
        ? (await _api.cukcukRecord(r.kind, r.externalId)).valueOrNull ?? r
        : r;
    if (!mounted) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(full.data);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(full.label ?? full.externalId),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pretty));
              Navigator.pop(context);
            },
            child: const Text('Sao chép JSON'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status?.valueOrNull;
    return InternalShell(
      title: 'Update dữ liệu CukCuk',
      subtitle: status == null
          ? null
          : status.configured
              ? 'Kết nối: ${status.domain} · tự đồng bộ mỗi 30 phút'
              : 'Chưa cấu hình kết nối trên server',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _loadStatus();
            _loadRecords();
          },
        ),
        FilledButton.icon(
          onPressed: _busy || status == null || !status.configured ? null : () => _sync('all'),
          icon: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          label: const Text('Đồng bộ tất cả'),
        ),
        const SizedBox(width: BananSpacing.sm),
      ],
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          if (status != null && !status.configured)
            Container(
              margin: const EdgeInsets.only(bottom: BananSpacing.lg),
              padding: const EdgeInsets.all(BananSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BananRadii.rmd,
              ),
              child: const Text(
                'Server chưa có CUKCUK_DOMAIN / CUKCUK_APP_ID / CUKCUK_SECRET_KEY. '
                'Lấy trong CukCuk → Thiết lập → Kết nối API, thêm vào .env.prod rồi khởi động lại backend.',
              ),
            ),
          if (status != null)
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
                final w = (c.maxWidth - BananSpacing.md * (columns - 1)) / columns;
                return Wrap(
                  spacing: BananSpacing.md,
                  runSpacing: BananSpacing.md,
                  children: [
                    for (final k in status.kinds)
                      SizedBox(
                        width: w,
                        child: _KindCard(
                          status: k,
                          selected: k.kind == _kind,
                          busy: _busy,
                          onSelect: () => _pickKind(k.kind),
                          onSync: status.configured ? () => _sync(k.kind) : null,
                        ),
                      ),
                  ],
                );
              },
            )
          else if (_status == null)
            const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            Text('Không tải được trạng thái.', style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: BananSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Tìm theo tên, mã, SĐT…',
                    isDense: true,
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _q = '';
                                _page = 1;
                              });
                              _loadRecords();
                            },
                          ),
                  ),
                  onSubmitted: (v) {
                    setState(() {
                      _q = v.trim();
                      _page = 1;
                    });
                    _loadRecords();
                  },
                ),
              ),
              if (_kind == 'customers') ...[
                const SizedBox(width: BananSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _applyCustomers,
                  icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                  label: const Text('Cập nhật khách lên website'),
                ),
              ],
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          _RecordsTable(
            kind: _kind,
            state: _records,
            page: _page,
            onPage: (p) {
              setState(() => _page = p);
              _loadRecords();
            },
            onOpen: _openRecord,
          ),
          const SizedBox(height: BananSpacing.xxl),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.status,
    required this.selected,
    required this.busy,
    required this.onSelect,
    this.onSync,
  });
  final CukcukKindStatus status;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelect,
      borderRadius: BananRadii.rmd,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          color: selected ? BananColors.primary.withValues(alpha: 0.06) : theme.colorScheme.surface,
          borderRadius: BananRadii.rmd,
          border: Border.all(color: selected ? BananColors.primary : theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(status.label, style: theme.textTheme.titleSmall)),
                Text('${status.count}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              status.lastSyncAt == null
                  ? 'Chưa đồng bộ'
                  : 'Lần cuối ${vnDateTime.format(status.lastSyncAt!.toLocal())} · ${status.lastFetched} dòng',
              style: theme.textTheme.bodySmall,
            ),
            if (status.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Lỗi: ${status.lastError}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: BananSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy || status.running ? null : onSync,
                icon: const Icon(Icons.sync, size: 16),
                label: Text(status.running ? 'Đang đồng bộ…' : 'Đồng bộ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({
    required this.kind,
    required this.state,
    required this.page,
    required this.onPage,
    required this.onOpen,
  });
  final String kind;
  final Result<CukcukPage, AppFailure>? state;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<CukcukRecord> onOpen;

  String _cell(CukcukRecord r, _Col c) {
    final raw = r.field(c.keys);
    if (raw.isEmpty) return '';
    if (c.money) {
      final n = double.tryParse(raw);
      return n == null ? raw : _vnd.format(n);
    }
    if (c.date) {
      final d = DateTime.tryParse(raw);
      return d == null ? raw : vnDate.format(d);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state;
    if (s == null) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    return s.when(
      failure: (f) => Text(f.message ?? f.code, style: TextStyle(color: theme.colorScheme.error)),
      success: (p) {
        if (p.items.isEmpty) {
          return Text('Chưa có dữ liệu. Bấm "Đồng bộ" để kéo từ CukCuk.',
              style: theme.textTheme.bodyMedium);
        }
        final cols = _columns[kind] ??
            const [
              _Col('Tên', ['Name'])
            ];
        final pages = (p.total / 50).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BananRadii.rmd,
                border: Border.all(color: theme.dividerColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: theme.textTheme.titleSmall,
                  columnSpacing: 20,
                  columns: [
                    for (final c in cols) DataColumn(label: Text(c.header), numeric: c.money),
                    if (kind == 'customers') const DataColumn(label: Text('Web')),
                    const DataColumn(label: Text('Cập nhật')),
                  ],
                  rows: [
                    for (final r in p.items)
                      DataRow(
                        onSelectChanged: (_) => onOpen(r),
                        cells: [
                          for (final c in cols)
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Text(_cell(r, c), overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          if (kind == 'customers')
                            DataCell(
                              r.linkedUserId == null
                                  ? const Text('—')
                                  : const Icon(Icons.check_circle,
                                      size: 16, color: BananColors.success),
                            ),
                          DataCell(
                            Text(
                              r.modifiedAt == null ? '' : vnDate.format(r.modifiedAt!.toLocal()),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            Row(
              children: [
                Text('${p.total} dòng', style: theme.textTheme.bodySmall),
                const Spacer(),
                IconButton(
                  onPressed: page > 1 ? () => onPage(page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Trang $page / ${pages == 0 ? 1 : pages}'),
                IconButton(
                  onPressed: page < pages ? () => onPage(page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
