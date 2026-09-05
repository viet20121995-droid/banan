import 'dart:convert';

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// "Nhật ký thao tác": every change a staff account made through the API,
/// newest first — who (email/role), when, from where (IP, browser), what
/// (method + path, status). One admin login is shared, so this is the record.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _q = TextEditingController();
  final _items = <AuditEntry>[];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  static String _day(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    final res = await ref.read(adminApiProvider).listAuditLog(
          q: _q.text.trim(),
          from: _day(_from),
          to: _day(_to),
          page: _page,
        );
    if (!mounted) return;
    res.when(
      success: (page) => setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _page++;
        _loading = false;
      }),
      failure: (f) => setState(() {
        _error = f.message ?? f.code;
        _loading = false;
      }),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (r == null) return;
    setState(() {
      _from = r.start;
      _to = r.end;
    });
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MerchantShell(
      title: 'Nhật ký thao tác',
      onRefresh: () => _load(reset: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BananSpacing.lg,
              BananSpacing.md,
              BananSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Email, đường dẫn hoặc IP',
                    ),
                    onSubmitted: (_) => _load(reset: true),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _from == null
                        ? 'Khoảng ngày'
                        : '${DateFormat('dd/MM').format(_from!)} – ${DateFormat('dd/MM').format(_to!)}',
                  ),
                ),
                if (_from != null)
                  IconButton(
                    tooltip: 'Bỏ lọc ngày',
                    onPressed: () {
                      setState(() {
                        _from = null;
                        _to = null;
                      });
                      _load(reset: true);
                    },
                    icon: const Icon(Icons.clear, size: 18),
                  ),
                Text(
                  '$_total dòng',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null && _items.isEmpty
                ? ErrorState(
                    message: _error!,
                    onRetry: () => _load(reset: true),
                  )
                : _items.isEmpty && !_loading
                    ? const EmptyState(
                        title: 'Chưa có thao tác nào',
                        message:
                            'Mọi thay đổi từ tài khoản nhân viên sẽ ghi lại ở đây.',
                        icon: Icons.history,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(BananSpacing.lg),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          if (i == _items.length) {
                            final more = _items.length < _total;
                            return Padding(
                              padding: const EdgeInsets.all(BananSpacing.md),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator()
                                    : more
                                        ? OutlinedButton(
                                            onPressed: () =>
                                                _load(reset: false),
                                            child: const Text('Tải thêm'),
                                          )
                                        : const SizedBox.shrink(),
                              ),
                            );
                          }
                          return _AuditRow(entry: _items[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = entry.status < 400;
    final when = DateFormat('dd/MM HH:mm:ss').format(entry.at.toLocal());
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 52,
        child: Text(
          '${entry.status}',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: ok ? BananColors.success : theme.colorScheme.error,
          ),
        ),
      ),
      title: Text(
        '${entry.method} ${entry.path}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Text(
        '$when · ${entry.email ?? '—'}${entry.role != null ? ' (${entry.role})' : ''}'
        ' · IP ${entry.ip ?? '—'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: entry.body == null
          ? null
          : () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('${entry.method} ${entry.path}'),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(entry.body),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
    );
  }
}
