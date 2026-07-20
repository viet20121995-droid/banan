import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// All campaigns (active + inactive) for the promotions manager.
final _campaignsProvider =
    FutureProvider.autoDispose<List<Campaign>>((ref) async {
  final res = await ref.watch(campaignsRepositoryProvider).list();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

final _vnd = NumberFormat.decimalPattern('vi_VN');

/// The campaign types that ship with a full editor (Phase 1 + 2 + 3).
const _editableTypes = <CampaignType>[
  CampaignType.productDiscount,
  CampaignType.categoryDiscount,
  CampaignType.flashSale,
  CampaignType.happyHour,
  CampaignType.buyXGetY,
  CampaignType.firstOrder,
  CampaignType.birthday,
  CampaignType.reactivation,
  CampaignType.membershipBenefit,
];

String _typeLabel(CampaignType t) {
  switch (t) {
    case CampaignType.productDiscount:
      return 'Giảm giá sản phẩm';
    case CampaignType.categoryDiscount:
      return 'Giảm giá danh mục';
    case CampaignType.flashSale:
      return 'Flash Sale';
    case CampaignType.happyHour:
      return 'Giờ vàng';
    case CampaignType.buyXGetY:
      return 'Mua X tặng Y';
    case CampaignType.firstOrder:
      return 'Ưu đãi đơn đầu';
    case CampaignType.birthday:
      return 'Sinh nhật';
    case CampaignType.reactivation:
      return 'Kéo khách quay lại';
    case CampaignType.membershipBenefit:
      return 'Ưu đãi hạng thành viên';
  }
}

const _weekdayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_campaignsProvider);
    return MerchantShell(
      title: 'Khuyến mãi',
      onRefresh: () async => ref.invalidate(_campaignsProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Tạo khuyến mãi'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_campaignsProvider),
        ),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return const EmptyState(
              title: 'Chưa có chương trình khuyến mãi',
              message:
                  'Tạo giảm giá sản phẩm, danh mục, Flash Sale hay Giờ vàng để '
                  'thu hút khách hàng.',
            );
          }
          // Group by type so the merchant sees campaigns clustered.
          final byType = <CampaignType, List<Campaign>>{};
          for (final c in campaigns) {
            byType.putIfAbsent(c.type, () => []).add(c);
          }
          final orderedTypes = [
            ..._editableTypes.where(byType.containsKey),
            ...byType.keys.where((t) => !_editableTypes.contains(t)),
          ];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_campaignsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                BananSpacing.lg,
                BananSpacing.lg,
                96,
              ),
              children: [
                for (final type in orderedTypes) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: BananSpacing.sm,
                      bottom: BananSpacing.xs,
                    ),
                    child: Text(
                      _typeLabel(type).toUpperCase(),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                    ),
                  ),
                  for (final c in byType[type]!) ...[
                    _CampaignCard(
                      campaign: c,
                      onEdit: () => _openEditor(context, ref, c),
                    ),
                    const SizedBox(height: BananSpacing.sm),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    Campaign? existing,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CampaignEditorSheet(existing: existing),
    );
    if (saved ?? false) ref.invalidate(_campaignsProvider);
  }
}

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.campaign, required this.onEdit});
  final Campaign campaign;
  final VoidCallback onEdit;

  /// Formats the kind/value pair shared by the per-line and per-order types.
  String _kindValueText() {
    final kind = campaign.config['kind'] as String?;
    final value = (campaign.config['value'] as num?)?.toDouble() ?? 0;
    if (kind == 'PERCENT') {
      return 'giảm ${value.toStringAsFixed(0)}%';
    }
    if (kind == 'FIXED') {
      return 'giảm ${_vnd.format(value)}₫';
    }
    return '—';
  }

  /// Membership-benefit list summary, e.g. "Hạng: Vàng 5% • Bạch kim 10%".
  /// Reads `config.tierValues` keyed by SILVER/GOLD/PLATINUM and formats each
  /// present tier per the shared kind (PERCENT = %, FIXED = ₫).
  String _membershipBenefitText() {
    final kind = campaign.config['kind'] as String?;
    final tierValues =
        (campaign.config['tierValues'] as Map?)?.cast<String, dynamic>() ??
            const {};
    String fmtValue(num v) =>
        kind == 'FIXED' ? '${_vnd.format(v)}₫' : '${_numText(v)}%';
    const order = [
      ('BRONZE', 'Đồng'),
      ('SILVER', 'Bạc'),
      ('GOLD', 'Vàng'),
      ('PLATINUM', 'Bạch kim'),
    ];
    final parts = <String>[];
    for (final (wire, label) in order) {
      final v = tierValues[wire] as num?;
      if (v != null && v > 0) parts.add('$label ${fmtValue(v)}');
    }
    return parts.isEmpty ? 'Chưa thiết lập hạng' : 'Hạng: ${parts.join(' • ')}';
  }

  /// Renders a number without a trailing ".0".
  static String _numText(num n) {
    if (n is int) return n.toString();
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _discountText() {
    final cfg = campaign.config;
    switch (campaign.type) {
      case CampaignType.firstOrder:
        final extra = (cfg['minSubtotal'] as num?)?.toDouble();
        final base = 'Đơn đầu • ${_kindValueText()}';
        return extra != null && extra > 0
            ? '$base (đơn từ ${_vnd.format(extra)}₫)'
            : base;
      case CampaignType.birthday:
        final days = (cfg['windowDays'] as num?)?.toInt() ?? 7;
        return 'Sinh nhật • ${_kindValueText()} (±$days ngày)';
      case CampaignType.reactivation:
        final days = (cfg['inactiveDays'] as num?)?.toInt() ?? 60;
        return 'Kéo lại • ${_kindValueText()} sau $days ngày';
      case CampaignType.buyXGetY:
        final buy = (cfg['buyQty'] as num?)?.toInt() ?? 0;
        final get = (cfg['getQty'] as num?)?.toInt() ?? 0;
        final pct = (cfg['getDiscountPct'] as num?)?.toInt() ?? 100;
        final gift = pct >= 100 ? 'tặng $get' : 'giảm $pct% cho $get';
        return 'Mua $buy $gift';
      case CampaignType.membershipBenefit:
        return _membershipBenefitText();
      case CampaignType.productDiscount:
      case CampaignType.categoryDiscount:
      case CampaignType.flashSale:
      case CampaignType.happyHour:
        final text = _kindValueText();
        return text == '—' ? '—' : 'Giảm ${text.substring('giảm '.length)}';
    }
  }

  String? _scheduleText() {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final parts = <String>[];
    if (campaign.startsAt != null) {
      parts.add('Từ ${df.format(campaign.startsAt!.toLocal())}');
    }
    if (campaign.endsAt != null) {
      parts.add('đến ${df.format(campaign.endsAt!.toLocal())}');
    }
    if (campaign.type == CampaignType.happyHour) {
      final start = campaign.config['startTime'] as String?;
      final end = campaign.config['endTime'] as String?;
      if (start != null && end != null) {
        final days =
            (campaign.config['daysOfWeek'] as List?)?.cast<num>() ?? const [];
        final dayText = days.isEmpty
            ? 'mỗi ngày'
            : days.map((d) => _weekdayLabels[d.toInt() % 7]).join(', ');
        parts.add('$start–$end ($dayText)');
      }
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schedule = _scheduleText();
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: campaign.isActive
              ? BananColors.gold
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (campaign.chainWide)
                _Tag(text: 'Toàn chuỗi', color: theme.colorScheme.outline),
              const SizedBox(width: BananSpacing.xs),
              _Tag(
                text: campaign.isActive ? 'Đang bật' : 'Đã tạm dừng',
                color: campaign.isActive
                    ? BananColors.success
                    : theme.colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(_discountText(), style: theme.textTheme.titleSmall),
          if (schedule != null) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(schedule, style: theme.textTheme.bodySmall),
          ],
          Text(
            campaign.usageLimit == null
                ? '${campaign.usedCount} lượt dùng · không giới hạn'
                : '${campaign.usedCount}/${campaign.usageLimit} lượt dùng',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: BananSpacing.lg),
          Row(
            children: [
              const Text('Đang bật'),
              Switch(
                value: campaign.isActive,
                onChanged: (v) => _toggleActive(context, ref, v),
              ),
              const Spacer(),
              if (campaign.type.hasEditor)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
              IconButton(
                tooltip: 'Xóa',
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final res = await ref
        .read(campaignsRepositoryProvider)
        .update(campaign.id, {'isActive': value});
    if (!context.mounted) return;
    res.when(
      success: (_) => ref.invalidate(_campaignsProvider),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khuyến mãi?'),
        content: Text(
          'Bạn có chắc muốn xóa "${campaign.name}"? Hành động này không thể '
          'hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final res =
        await ref.read(campaignsRepositoryProvider).delete(campaign.id);
    if (!context.mounted) return;
    res.when(
      success: (_) => ref.invalidate(_campaignsProvider),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Editor ──────────────────────────────────────────────────────────────

class _CampaignEditorSheet extends ConsumerStatefulWidget {
  const _CampaignEditorSheet({this.existing});
  final Campaign? existing;

  @override
  ConsumerState<_CampaignEditorSheet> createState() =>
      _CampaignEditorSheetState();
}

class _CampaignEditorSheetState extends ConsumerState<_CampaignEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();

  // First order (optional minimum subtotal).
  final _minSubtotal = TextEditingController();
  // Birthday window / reactivation inactivity window.
  final _windowDays = TextEditingController(text: '7');
  final _inactiveDays = TextEditingController(text: '60');
  // Buy X get Y.
  final _buyQty = TextEditingController(text: '2');
  final _getQty = TextEditingController(text: '1');
  final _getDiscountPct = TextEditingController(text: '100');
  // Membership benefit — per-tier value (blank/0 = tier excluded).
  final _bronzeValue = TextEditingController();
  final _silverValue = TextEditingController();
  final _goldValue = TextEditingController();
  final _platinumValue = TextEditingController();

  CampaignType _type = CampaignType.productDiscount;
  String _kind = 'PERCENT'; // PERCENT | FIXED
  bool _isActive = true;

  // Scope selections.
  final Set<String> _productIds = {};
  final Set<String> _categoryIds = {};

  // Schedule.
  DateTime? _startsAt;
  DateTime? _endsAt;

  // Happy hour.
  TimeOfDay _startTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);
  final Set<int> _daysOfWeek = {}; // empty = every day

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _type = c.type;
      _name.text = c.name;
      _isActive = c.isActive;
      _startsAt = c.startsAt;
      _endsAt = c.endsAt;
      final cfg = c.config;
      _kind = (cfg['kind'] as String?) ?? 'PERCENT';
      final v = cfg['value'];
      if (v != null) _value.text = _numText(v as num);
      for (final id in (cfg['productIds'] as List?) ?? const []) {
        _productIds.add(id as String);
      }
      for (final id in (cfg['categoryIds'] as List?) ?? const []) {
        _categoryIds.add(id as String);
      }
      _startTime = _parseTime(cfg['startTime'] as String?) ?? _startTime;
      _endTime = _parseTime(cfg['endTime'] as String?) ?? _endTime;
      for (final d in (cfg['daysOfWeek'] as List?) ?? const []) {
        _daysOfWeek.add((d as num).toInt());
      }
      // Phase-2 type-specific fields.
      final minSubtotal = cfg['minSubtotal'] as num?;
      if (minSubtotal != null) _minSubtotal.text = _numText(minSubtotal);
      final windowDays = cfg['windowDays'] as num?;
      if (windowDays != null) _windowDays.text = '${windowDays.toInt()}';
      final inactiveDays = cfg['inactiveDays'] as num?;
      if (inactiveDays != null) _inactiveDays.text = '${inactiveDays.toInt()}';
      final buyQty = cfg['buyQty'] as num?;
      if (buyQty != null) _buyQty.text = '${buyQty.toInt()}';
      final getQty = cfg['getQty'] as num?;
      if (getQty != null) _getQty.text = '${getQty.toInt()}';
      final getDiscountPct = cfg['getDiscountPct'] as num?;
      if (getDiscountPct != null) {
        _getDiscountPct.text = '${getDiscountPct.toInt()}';
      }
      // Phase-3 membership benefit — per-tier values.
      final tierValues = (cfg['tierValues'] as Map?)?.cast<String, dynamic>();
      if (tierValues != null) {
        final bronze = tierValues['BRONZE'] as num?;
        if (bronze != null) _bronzeValue.text = _numText(bronze);
        final silver = tierValues['SILVER'] as num?;
        if (silver != null) _silverValue.text = _numText(silver);
        final gold = tierValues['GOLD'] as num?;
        if (gold != null) _goldValue.text = _numText(gold);
        final platinum = tierValues['PLATINUM'] as num?;
        if (platinum != null) _platinumValue.text = _numText(platinum);
      }
    }
  }

  /// Renders a number without a trailing ".0" so the field shows "10" not
  /// "10.0" when the backend returns an int-valued double.
  static String _numText(num n) {
    if (n is int) return n.toString();
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _minSubtotal.dispose();
    _windowDays.dispose();
    _inactiveDays.dispose();
    _buyQty.dispose();
    _getQty.dispose();
    _getDiscountPct.dispose();
    _bronzeValue.dispose();
    _silverValue.dispose();
    _goldValue.dispose();
    _platinumValue.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _wantsProductScope =>
      _type == CampaignType.productDiscount ||
      _type == CampaignType.flashSale ||
      _type == CampaignType.happyHour ||
      _type == CampaignType.buyXGetY;

  bool get _wantsCategoryScope =>
      _type == CampaignType.categoryDiscount ||
      _type == CampaignType.flashSale ||
      _type == CampaignType.happyHour ||
      _type == CampaignType.buyXGetY;

  bool get _productScopeRequired => _type == CampaignType.productDiscount;
  bool get _categoryScopeRequired => _type == CampaignType.categoryDiscount;

  /// True for types whose primary discount is a single shared kind/value pair
  /// (percent or fixed amount). Buy X Get Y carries its own quantity-based
  /// config; Membership Benefit carries a per-tier value map — both have no
  /// single kind/value field.
  bool get _usesKindValue =>
      _type != CampaignType.buyXGetY &&
      _type != CampaignType.membershipBenefit;

  /// Whether the PERCENT/FIXED kind chips apply — shared by the single-value
  /// types and Membership Benefit (whose per-tier values use the same kind).
  bool get _usesKind => _usesKindValue || _type == CampaignType.membershipBenefit;

  Map<String, dynamic> _buildConfig() {
    final value = num.tryParse(_value.text.trim()) ?? 0;
    // Buy X Get Y has its own quantity shape (no kind/value); Membership
    // Benefit carries the shared kind plus a per-tier value map (no single
    // value); everything else shares a single kind/value pair.
    final Map<String, dynamic> config;
    if (_type == CampaignType.buyXGetY) {
      config = <String, dynamic>{};
    } else if (_type == CampaignType.membershipBenefit) {
      config = <String, dynamic>{'kind': _kind};
    } else {
      config = <String, dynamic>{'kind': _kind, 'value': value};
    }
    switch (_type) {
      case CampaignType.productDiscount:
        config['productIds'] = _productIds.toList();
      case CampaignType.categoryDiscount:
        config['categoryIds'] = _categoryIds.toList();
      case CampaignType.flashSale:
        if (_productIds.isNotEmpty) {
          config['productIds'] = _productIds.toList();
        }
        if (_categoryIds.isNotEmpty) {
          config['categoryIds'] = _categoryIds.toList();
        }
      case CampaignType.happyHour:
        if (_productIds.isNotEmpty) {
          config['productIds'] = _productIds.toList();
        }
        if (_categoryIds.isNotEmpty) {
          config['categoryIds'] = _categoryIds.toList();
        }
        config['startTime'] = _fmtTime(_startTime);
        config['endTime'] = _fmtTime(_endTime);
        config['daysOfWeek'] = _daysOfWeek.toList()..sort();
      case CampaignType.firstOrder:
        // Order-level discount; optional minimum subtotal gate.
        final minSubtotal = num.tryParse(_minSubtotal.text.trim());
        if (minSubtotal != null && minSubtotal > 0) {
          config['minSubtotal'] = minSubtotal;
        }
      case CampaignType.birthday:
        config['windowDays'] = int.tryParse(_windowDays.text.trim()) ?? 7;
      case CampaignType.reactivation:
        config['inactiveDays'] = int.tryParse(_inactiveDays.text.trim()) ?? 60;
      case CampaignType.buyXGetY:
        config['buyQty'] = int.tryParse(_buyQty.text.trim()) ?? 0;
        config['getQty'] = int.tryParse(_getQty.text.trim()) ?? 0;
        config['getDiscountPct'] =
            int.tryParse(_getDiscountPct.text.trim()) ?? 100;
        // Optional scope (empty = whole menu).
        if (_productIds.isNotEmpty) {
          config['productIds'] = _productIds.toList();
        }
        if (_categoryIds.isNotEmpty) {
          config['categoryIds'] = _categoryIds.toList();
        }
      // Membership benefit — per-tier value map. Omit a tier whose field is
      // blank or 0. No product/category scope.
      case CampaignType.membershipBenefit:
        final tierValues = <String, dynamic>{};
        final bronze = num.tryParse(_bronzeValue.text.trim());
        if (bronze != null && bronze > 0) tierValues['BRONZE'] = bronze;
        final silver = num.tryParse(_silverValue.text.trim());
        if (silver != null && silver > 0) tierValues['SILVER'] = silver;
        final gold = num.tryParse(_goldValue.text.trim());
        if (gold != null && gold > 0) tierValues['GOLD'] = gold;
        final platinum = num.tryParse(_platinumValue.text.trim());
        if (platinum != null && platinum > 0) {
          tierValues['PLATINUM'] = platinum;
        }
        config['tierValues'] = tierValues;
    }
    return config;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productScopeRequired && _productIds.isEmpty) {
      setState(() => _error = 'Chọn ít nhất một sản phẩm.');
      return;
    }
    if (_categoryScopeRequired && _categoryIds.isEmpty) {
      setState(() => _error = 'Chọn ít nhất một danh mục.');
      return;
    }
    if (_type == CampaignType.buyXGetY) {
      final buy = int.tryParse(_buyQty.text.trim()) ?? 0;
      final get = int.tryParse(_getQty.text.trim()) ?? 0;
      if (buy < 1 || get < 1) {
        setState(() => _error = 'Số lượng "Mua" và "Tặng" phải từ 1 trở lên.');
        return;
      }
    }
    if (_type == CampaignType.flashSale) {
      if (_startsAt == null || _endsAt == null) {
        setState(() => _error = 'Flash Sale cần thời gian bắt đầu và kết thúc.');
        return;
      }
    }
    if (_type == CampaignType.membershipBenefit) {
      final tierValues = _buildConfig()['tierValues'] as Map;
      if (tierValues.isEmpty) {
        setState(() {
          _error = 'Nhập ưu đãi cho ít nhất một hạng '
              '(Bạc, Vàng hoặc Bạch kim).';
        });
        return;
      }
    }
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      setState(() => _error = 'Thời gian kết thúc phải sau thời gian bắt đầu.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'type': _type.toWire(),
      'name': _name.text.trim(),
      'isActive': _isActive,
      'config': _buildConfig(),
      'startsAt': _startsAt?.toUtc().toIso8601String(),
      'endsAt': _endsAt?.toUtc().toIso8601String(),
    };

    final api = ref.read(campaignsRepositoryProvider);
    final res = _isEdit
        ? await api.update(widget.existing!.id, body)
        : await api.create(body);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  Future<void> _pickDateTime(bool start) async {
    final now = DateTime.now();
    final base = (start ? _startsAt : _endsAt) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    setState(() {
      if (start) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BananSpacing.lg,
        0,
        BananSpacing.lg,
        bottom + BananSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _isEdit ? 'Sửa khuyến mãi' : 'Tạo khuyến mãi',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: BananSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                margin: const EdgeInsets.only(bottom: BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color:
                      theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                ),
                child: Text(_error!),
              ),
            // Type selector — locked on edit (changing type would invalidate
            // the config shape).
            Text('Loại khuyến mãi', style: theme.textTheme.labelLarge),
            const SizedBox(height: BananSpacing.xs),
            Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.xs,
              children: [
                for (final t in _editableTypes)
                  ChoiceChip(
                    label: Text(_typeLabel(t)),
                    selected: _type == t,
                    onSelected: _isEdit
                        ? null
                        : (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: BananSpacing.md),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Tên chương trình',
                hintText: 'VD: Flash Sale cuối tuần',
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nhập tên chương trình'
                  : null,
            ),
            // Kind chips: shared by the single-value types AND Membership
            // Benefit (its per-tier values use the same %/₫ kind).
            if (_usesKind) ...[
              const SizedBox(height: BananSpacing.md),
              Text('Hình thức giảm', style: theme.textTheme.labelLarge),
              const SizedBox(height: BananSpacing.xs),
              Wrap(
                spacing: BananSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Giảm theo %'),
                    selected: _kind == 'PERCENT',
                    onSelected: (_) => setState(() => _kind = 'PERCENT'),
                  ),
                  ChoiceChip(
                    label: const Text('Giảm tiền (₫)'),
                    selected: _kind == 'FIXED',
                    onSelected: (_) => setState(() => _kind = 'FIXED'),
                  ),
                ],
              ),
            ],
            // Single value field — every kind/value type except Membership
            // Benefit (which has three per-tier fields instead).
            if (_usesKindValue) ...[
              const SizedBox(height: BananSpacing.sm),
              TextFormField(
                controller: _value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      _kind == 'PERCENT' ? 'Phần trăm (1–100)' : 'Số tiền (₫)',
                ),
                validator: (v) {
                  if (!_usesKindValue) return null;
                  final n = num.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Nhập một số';
                  if (_kind == 'PERCENT' && n > 100) return 'Tối đa 100%';
                  return null;
                },
              ),
            ],
            // Membership benefit — three per-tier value fields. Blank/0 = the
            // tier is excluded. No product/category scope.
            if (_type == CampaignType.membershipBenefit) ...[
              const SizedBox(height: BananSpacing.md),
              Text(
                'Ưu đãi theo hạng',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'Để trống một hạng nếu hạng đó không được ưu đãi.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: BananSpacing.sm),
              _TierValueField(
                controller: _bronzeValue,
                label: 'Đồng (BRONZE)',
                kind: _kind,
              ),
              const SizedBox(height: BananSpacing.sm),
              _TierValueField(
                controller: _silverValue,
                label: 'Bạc (SILVER)',
                kind: _kind,
              ),
              const SizedBox(height: BananSpacing.sm),
              _TierValueField(
                controller: _goldValue,
                label: 'Vàng (GOLD)',
                kind: _kind,
              ),
              const SizedBox(height: BananSpacing.sm),
              _TierValueField(
                controller: _platinumValue,
                label: 'Bạch kim (PLATINUM)',
                kind: _kind,
              ),
            ],
            // First order — optional minimum subtotal gate.
            if (_type == CampaignType.firstOrder) ...[
              const SizedBox(height: BananSpacing.md),
              TextFormField(
                controller: _minSubtotal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đơn tối thiểu (₫), tuỳ chọn',
                  hintText: 'Trống = áp dụng mọi đơn đầu',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  final n = num.tryParse(t);
                  if (n == null || n < 0) return 'Nhập một số hợp lệ';
                  return null;
                },
              ),
            ],
            // Birthday — window of days around the birthday.
            if (_type == CampaignType.birthday) ...[
              const SizedBox(height: BananSpacing.md),
              TextFormField(
                controller: _windowDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số ngày quanh sinh nhật',
                  hintText: 'VD: 7 (áp dụng ±7 ngày)',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Nhập số ngày';
                  return null;
                },
              ),
            ],
            // Reactivation — inactivity threshold in days.
            if (_type == CampaignType.reactivation) ...[
              const SizedBox(height: BananSpacing.md),
              TextFormField(
                controller: _inactiveDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số ngày không mua',
                  hintText: 'VD: 60 (khách không mua 60 ngày)',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1) return 'Nhập số ngày';
                  return null;
                },
              ),
            ],
            // Buy X Get Y — quantity-based config.
            if (_type == CampaignType.buyXGetY) ...[
              const SizedBox(height: BananSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyQty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mua'),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1) return '≥ 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _getQty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tặng'),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1) return '≥ 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.sm),
              TextFormField(
                controller: _getDiscountPct,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giảm % cho phần tặng',
                  hintText: '100 = miễn phí',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1 || n > 100) return '1–100';
                  return null;
                },
              ),
            ],
            const SizedBox(height: BananSpacing.md),
            // Scope pickers.
            if (_wantsProductScope)
              _ScopePickerTile(
                title: 'Sản phẩm áp dụng'
                    '${_productScopeRequired ? '' : ' (trống = cả menu)'}',
                count: _productIds.length,
                onTap: _pickProducts,
              ),
            if (_wantsCategoryScope) ...[
              const SizedBox(height: BananSpacing.sm),
              _ScopePickerTile(
                title: 'Danh mục áp dụng'
                    '${_categoryScopeRequired ? '' : ' (trống = cả menu)'}',
                count: _categoryIds.length,
                onTap: _pickCategories,
              ),
            ],
            // Schedule for flash sale (required) + optional for others.
            if (_type == CampaignType.flashSale) ...[
              const SizedBox(height: BananSpacing.md),
              Text('Khung giờ Flash Sale', style: theme.textTheme.labelLarge),
              const SizedBox(height: BananSpacing.xs),
              _DateTimeRow(
                startsAt: _startsAt,
                endsAt: _endsAt,
                onPickStart: () => _pickDateTime(true),
                onPickEnd: () => _pickDateTime(false),
              ),
            ],
            if (_type == CampaignType.happyHour) ...[
              const SizedBox(height: BananSpacing.md),
              Text('Khung giờ vàng', style: theme.textTheme.labelLarge),
              const SizedBox(height: BananSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text('Bắt đầu: ${_fmtTime(_startTime)}'),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text('Kết thúc: ${_fmtTime(_endTime)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.sm),
              Text(
                'Ngày trong tuần (trống = mỗi ngày)',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: BananSpacing.xs),
              Wrap(
                spacing: BananSpacing.xs,
                children: [
                  for (var d = 0; d < 7; d++)
                    FilterChip(
                      label: Text(_weekdayLabels[d]),
                      selected: _daysOfWeek.contains(d),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _daysOfWeek.add(d);
                        } else {
                          _daysOfWeek.remove(d);
                        }
                      }),
                    ),
                ],
              ),
            ],
            // Optional schedule window for non-flash types.
            if (_type == CampaignType.productDiscount ||
                _type == CampaignType.categoryDiscount ||
                _type == CampaignType.happyHour) ...[
              const SizedBox(height: BananSpacing.md),
              Text(
                'Thời gian áp dụng (tuỳ chọn)',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: BananSpacing.xs),
              _DateTimeRow(
                startsAt: _startsAt,
                endsAt: _endsAt,
                onPickStart: () => _pickDateTime(true),
                onPickEnd: () => _pickDateTime(false),
                onClear: (_startsAt != null || _endsAt != null)
                    ? () => setState(() {
                          _startsAt = null;
                          _endsAt = null;
                        })
                    : null,
              ),
            ],
            const SizedBox(height: BananSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kích hoạt ngay'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: BananSpacing.md),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Lưu thay đổi' : 'Tạo khuyến mãi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickProducts() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductMultiSelectSheet(initial: _productIds),
    );
    if (result != null) {
      setState(() {
        _productIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _pickCategories() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryMultiSelectSheet(initial: _categoryIds),
    );
    if (result != null) {
      setState(() {
        _categoryIds
          ..clear()
          ..addAll(result);
      });
    }
  }
}

/// A single membership-tier value input. Optional (blank = the tier is
/// excluded); when filled, validates as a positive number, capped at 100
/// for the PERCENT kind. The suffix reflects the current kind (% / ₫).
class _TierValueField extends StatelessWidget {
  const _TierValueField({
    required this.controller,
    required this.label,
    required this.kind,
  });
  final TextEditingController controller;
  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final isPercent = kind == 'PERCENT';
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: isPercent ? '%' : '₫',
        hintText: 'Trống = không ưu đãi',
      ),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return null; // tier excluded
        final n = num.tryParse(t);
        if (n == null || n < 0) return 'Nhập một số hợp lệ';
        if (isPercent && n > 100) return 'Tối đa 100%';
        return null;
      },
    );
  }
}

class _ScopePickerTile extends StatelessWidget {
  const _ScopePickerTile({
    required this.title,
    required this.count,
    required this.onTap,
  });
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.md,
          vertical: BananSpacing.md,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            count == 0 ? 'Tất cả' : 'Đã chọn $count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.startsAt,
    required this.endsAt,
    required this.onPickStart,
    required this.onPickEnd,
    this.onClear,
  });
  final DateTime? startsAt;
  final DateTime? endsAt;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM HH:mm');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPickStart,
                child: Text(
                  startsAt == null
                      ? 'Bắt đầu'
                      : 'Từ: ${df.format(startsAt!.toLocal())}',
                ),
              ),
            ),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: onPickEnd,
                child: Text(
                  endsAt == null
                      ? 'Kết thúc'
                      : 'Đến: ${df.format(endsAt!.toLocal())}',
                ),
              ),
            ),
          ],
        ),
        if (onClear != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClear,
              child: const Text('Xóa lịch'),
            ),
          ),
      ],
    );
  }
}

// ─── Multi-select sheets ───────────────────────────────────────────────────

/// Loads merchant products and lets the admin tick a subset.
class _ProductMultiSelectSheet extends ConsumerStatefulWidget {
  const _ProductMultiSelectSheet({required this.initial});
  final Set<String> initial;

  @override
  ConsumerState<_ProductMultiSelectSheet> createState() =>
      _ProductMultiSelectSheetState();
}

class _ProductMultiSelectSheetState
    extends ConsumerState<_ProductMultiSelectSheet> {
  late final Set<String> _selected = {...widget.initial};
  late final Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Product>> _load() async {
    final res = await ref
        .read(catalogRepositoryProvider)
        .merchantProducts(perPage: 200);
    return res.when(
      success: (page) => page.items,
      failure: (f) => throw Exception(authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BananSpacing.lg,
        0,
        BananSpacing.lg,
        BananSpacing.lg,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chọn sản phẩm', style: theme.textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Lỗi: ${snap.error}'));
                  }
                  final products = snap.data ?? const [];
                  if (products.isEmpty) {
                    return const EmptyState(
                      title: 'Chưa có sản phẩm',
                      message: 'Tạo sản phẩm ở mục Thực đơn trước.',
                      icon: Icons.cake_outlined,
                    );
                  }
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return CheckboxListTile(
                        title: Text(p.name),
                        value: _selected.contains(p.id),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text('Xong (${_selected.length})'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads categories and lets the admin tick a subset.
class _CategoryMultiSelectSheet extends ConsumerStatefulWidget {
  const _CategoryMultiSelectSheet({required this.initial});
  final Set<String> initial;

  @override
  ConsumerState<_CategoryMultiSelectSheet> createState() =>
      _CategoryMultiSelectSheetState();
}

class _CategoryMultiSelectSheetState
    extends ConsumerState<_CategoryMultiSelectSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(categoriesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BananSpacing.lg,
        0,
        BananSpacing.lg,
        BananSpacing.lg,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chọn danh mục', style: theme.textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (categories) {
                  if (categories.isEmpty) {
                    return const EmptyState(
                      title: 'Chưa có danh mục',
                      message: 'Tạo danh mục ở mục Danh mục trước.',
                      icon: Icons.category_outlined,
                    );
                  }
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final c = categories[i];
                      return CheckboxListTile(
                        title: Text(c.name),
                        value: _selected.contains(c.id),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected.add(c.id);
                          } else {
                            _selected.remove(c.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text('Xong (${_selected.length})'),
            ),
          ],
        ),
      ),
    );
  }
}
