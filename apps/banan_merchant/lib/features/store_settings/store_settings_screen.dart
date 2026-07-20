import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Settings panel: pause toggle, weekly opening hours, minimum order, lead
/// time, and blackout calendar. Single screen with collapsible sections —
/// the merchant typically configures it once, then occasionally toggles
/// pause / adds a blackout date.
class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  late Future<StoreSettings> _settingsFuture;
  late Future<List<StoreBlackoutDate>> _blackoutsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(storeSettingsRepositoryProvider);
    _settingsFuture = repo.getSettings().then(
          (r) => r.when(
            success: (s) => s,
            failure: (f) => throw Exception(authFailureMessage(f)),
          ),
        );
    _blackoutsFuture = repo.listBlackouts().then(
          (r) => r.when(
            success: (list) => list,
            failure: (f) => throw Exception(authFailureMessage(f)),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MerchantShell(
      title: 'Cài đặt cửa hàng',
      onRefresh: () async => setState(_reload),
      body: FutureBuilder<StoreSettings>(
        future: _settingsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorState(
              message: snap.error?.toString() ?? 'Không tải được cài đặt.',
              onRetry: () => setState(_reload),
            );
          }
          return _Body(
            initial: snap.data!,
            blackoutsFuture: _blackoutsFuture,
            onChanged: () => setState(_reload),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.initial,
    required this.blackoutsFuture,
    required this.onChanged,
  });

  final StoreSettings initial;
  final Future<List<StoreBlackoutDate>> blackoutsFuture;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late bool _isPaused;
  late bool _isPickupPaused;
  late bool _isDeliveryPaused;
  late TextEditingController _pauseReason;
  late TextEditingController _minOrder;
  late TextEditingController _defaultLeadHours;
  late Map<String, List<List<String>>> _hours;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _isPaused = widget.initial.isPaused;
    _isPickupPaused = widget.initial.isPickupPaused;
    _isDeliveryPaused = widget.initial.isDeliveryPaused;
    _pauseReason = TextEditingController(text: widget.initial.pauseReason ?? '');
    _minOrder = TextEditingController(text: '${widget.initial.minOrderVnd}');
    _defaultLeadHours = TextEditingController(
      text: '${widget.initial.defaultLeadHours}',
    );
    // Deep-copy so edits don't mutate the source.
    _hours = {
      for (final e in widget.initial.openingHours.entries)
        e.key: [for (final s in e.value) [...s]],
    };
  }

  @override
  void dispose() {
    _pauseReason.dispose();
    _minOrder.dispose();
    _defaultLeadHours.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    final patch = StoreSettingsPatch(
      isPaused: _isPaused,
      isPickupPaused: _isPickupPaused,
      isDeliveryPaused: _isDeliveryPaused,
      pauseReason: _pauseReason.text.trim(),
      minOrderVnd: int.tryParse(_minOrder.text.trim()) ?? 0,
      defaultLeadHours: int.tryParse(_defaultLeadHours.text.trim()) ?? 0,
      openingHours: _hours,
    );
    final res = await ref
        .read(storeSettingsRepositoryProvider)
        .updateSettings(patch);
    if (!mounted) return;
    setState(() => _savingSettings = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt.')),
        );
        widget.onChanged();
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Pause toggles ───────────────────────────────────────
                _Section(
                  title: 'Trạng thái nhận đơn',
                  description:
                      'Công tắc tổng dừng nhận mọi đơn. Hai công tắc kênh '
                      'dưới chỉ áp dụng riêng, ví dụ hết shipper thì tạm '
                      'dừng giao, nhưng vẫn nhận khách đến quầy.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isPaused,
                        onChanged: (v) => setState(() => _isPaused = v),
                        title: Text(
                          _isPaused
                              ? 'Tạm dừng tất cả'
                              : 'Đang nhận đơn bình thường',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: const Text(
                          'Bật để chặn cả pickup và giao hàng.',
                        ),
                      ),
                      const Divider(height: BananSpacing.lg),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isPickupPaused,
                        onChanged: _isPaused
                            ? null
                            : (v) => setState(() => _isPickupPaused = v),
                        secondary: const Icon(Icons.storefront_outlined),
                        title: Text(
                          'Tạm dừng đơn tự lấy (PICKUP)',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _isPickupPaused
                              ? 'Khách không thể chọn chi nhánh này để đến lấy.'
                              : 'Đang nhận khách đến lấy tại quầy.',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isDeliveryPaused,
                        onChanged: _isPaused
                            ? null
                            : (v) => setState(() => _isDeliveryPaused = v),
                        secondary: const Icon(Icons.delivery_dining_outlined),
                        title: Text(
                          'Tạm dừng giao hàng (DELIVERY)',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _isDeliveryPaused
                              ? 'Khách không thể chọn chi nhánh này để giao hàng.'
                              : 'Đang nhận đơn giao hàng.',
                        ),
                      ),
                      if (_isPaused ||
                          _isPickupPaused ||
                          _isDeliveryPaused) ...[
                        const SizedBox(height: BananSpacing.sm),
                        TextField(
                          controller: _pauseReason,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Lý do (hiển thị cho khách)',
                            hintText:
                                'VD: Hết shipper, mở lại lúc 15:00 hôm nay.',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Order rules ─────────────────────────────────────────
                _Section(
                  title: 'Quy tắc đặt hàng',
                  description:
                      'Giá trị đơn tối thiểu và thời gian báo trước áp dụng cho '
                      'mọi sản phẩm. Mỗi sản phẩm có thể bật override riêng.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _minOrder,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Đơn tối thiểu (₫)',
                          helperText: int.tryParse(_minOrder.text) != null &&
                                  int.parse(_minOrder.text) > 0
                              ? 'Tối thiểu ${money.format(int.parse(_minOrder.text))}'
                              : '0 = không giới hạn',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      TextField(
                        controller: _defaultLeadHours,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian báo trước mặc định (giờ)',
                          helperText:
                              'Khách phải đặt trước ít nhất số giờ này. '
                              '0 = không yêu cầu.',
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Weekly hours ────────────────────────────────────────
                _Section(
                  title: 'Giờ mở cửa hàng tuần',
                  description:
                      'Mỗi thứ có thể có một hoặc nhiều khoảng giờ. '
                      'Ngày không có khoảng = nghỉ.',
                  child: _WeeklyHoursEditor(
                    hours: _hours,
                    onChanged: (next) => setState(() => _hours = next),
                  ),
                ),

                // ── Save bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(
                    top: BananSpacing.sm,
                    bottom: BananSpacing.xl,
                  ),
                  child: FilledButton.icon(
                    onPressed: _savingSettings ? null : _saveSettings,
                    icon: _savingSettings
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Lưu cài đặt'),
                  ),
                ),

                // ── Blackouts ───────────────────────────────────────────
                _Section(
                  title: 'Ngày nghỉ / không nhận đơn',
                  description:
                      'Đánh dấu các ngày đóng cửa (Tết, lễ, đi vắng). '
                      'Khách không thể đặt đơn cho những ngày này.',
                  child: _BlackoutsEditor(
                    future: widget.blackoutsFuture,
                    onChanged: widget.onChanged,
                  ),
                ),

                // ── Read-only info ──────────────────────────────────────
                _Section(
                  title: 'Thông tin khác',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        theme,
                        'Cảnh báo "đến giờ" cho bếp',
                        '${widget.initial.preparationLeadMinutes} phút '
                            'trước thời gian giao/lấy',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.huge),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: BananSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
}

// ─── Weekly hours editor ───────────────────────────────────────────────────

/// Vietnamese day names paired with the backend's short-key. Mon-first.
const _dayOrder = <(String key, String label)>[
  ('mon', 'Thứ 2'),
  ('tue', 'Thứ 3'),
  ('wed', 'Thứ 4'),
  ('thu', 'Thứ 5'),
  ('fri', 'Thứ 6'),
  ('sat', 'Thứ 7'),
  ('sun', 'Chủ nhật'),
];

class _WeeklyHoursEditor extends StatelessWidget {
  const _WeeklyHoursEditor({
    required this.hours,
    required this.onChanged,
  });

  final Map<String, List<List<String>>> hours;
  final ValueChanged<Map<String, List<List<String>>>> onChanged;

  void _setWindows(String day, List<List<String>> next) {
    final updated = {
      for (final e in hours.entries) e.key: [for (final s in e.value) [...s]],
    };
    updated[day] = next;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in _dayOrder)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.only(top: BananSpacing.sm),
                    child: Text(d.$2, style: theme.textTheme.titleSmall),
                  ),
                ),
                Expanded(
                  child: _DayWindowsEditor(
                    windows: hours[d.$1] ?? const [],
                    onChanged: (next) => _setWindows(d.$1, next),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayWindowsEditor extends StatelessWidget {
  const _DayWindowsEditor({required this.windows, required this.onChanged});

  final List<List<String>> windows;
  final ValueChanged<List<List<String>>> onChanged;

  Future<void> _pick(BuildContext context, int idx, int side) async {
    final current = windows[idx][side];
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final next = [for (final w in windows) [...w]];
    next[idx][side] = hhmm;
    onChanged(next);
  }

  void _addWindow() {
    final next = [for (final w in windows) [...w]];
    next.add(['09:00', '21:00']);
    onChanged(next);
  }

  void _removeWindow(int idx) {
    final next = [for (final w in windows) [...w]]..removeAt(idx);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Row(
          children: [
            Text('Nghỉ', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: BananSpacing.md),
            TextButton.icon(
              onPressed: _addWindow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm khung giờ'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < windows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => _pick(context, i, 0),
                  child: Text(windows[i][0]),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: BananSpacing.xs),
                  child: Text('–'),
                ),
                OutlinedButton(
                  onPressed: () => _pick(context, i, 1),
                  child: Text(windows[i][1]),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Xoá khung giờ',
                  onPressed: () => _removeWindow(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _addWindow,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm khung giờ'),
        ),
      ],
    );
  }
}

// ─── Blackouts editor ──────────────────────────────────────────────────────

class _BlackoutsEditor extends ConsumerStatefulWidget {
  const _BlackoutsEditor({required this.future, required this.onChanged});
  final Future<List<StoreBlackoutDate>> future;
  final VoidCallback onChanged;

  @override
  ConsumerState<_BlackoutsEditor> createState() => _BlackoutsEditorState();
}

class _BlackoutsEditorState extends ConsumerState<_BlackoutsEditor> {
  Future<void> _add() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đóng cửa ngày ${_fmtDate(picked)}?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Lý do (tuỳ chọn)',
            hintText: 'VD: Tết Nguyên đán',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;
    final iso = _isoDate(picked);
    final res = await ref.read(storeSettingsRepositoryProvider).addBlackout(
          isoDate: iso,
          reason: reason.isEmpty ? null : reason,
        );
    if (!mounted) return;
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm ngày ${_fmtDate(picked)}.')),
        );
        widget.onChanged();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  Future<void> _remove(StoreBlackoutDate row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá ngày ${_fmtDate(row.date)}?'),
        content: const Text('Cửa hàng sẽ mở lại bình thường vào ngày này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ref
        .read(storeSettingsRepositoryProvider)
        .removeBlackout(row.id);
    if (!mounted) return;
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá.')),
        );
        widget.onChanged();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => DateFormat('EEE, dd/MM/yyyy', 'vi_VN').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<StoreBlackoutDate>>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: BananSpacing.md),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final list = (snap.data ?? const <StoreBlackoutDate>[]).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (list.isEmpty)
              Text(
                'Chưa có ngày nghỉ nào.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...list.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(_fmtDate(r.date)),
                  subtitle: r.reason != null && r.reason!.isNotEmpty
                      ? Text(r.reason!)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(r),
                  ),
                ),
              ),
            const SizedBox(height: BananSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_outlined),
                label: const Text('Thêm ngày nghỉ'),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Section card ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BananSpacing.lg),
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (description != null) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(description!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: BananSpacing.md),
          child,
        ],
      ),
    );
  }
}
