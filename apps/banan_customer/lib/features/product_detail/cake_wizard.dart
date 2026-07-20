import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Candle type values stored in the personalization JSON.
/// `regular` = nến thường, `number` = nến số (digit candles by age),
/// `spiral` = nến xoắn. A null/absent type means "no candles".
abstract final class CandleType {
  static const String regular = 'regular';
  static const String number = 'number';
  static const String spiral = 'spiral';
}

/// Builds the human-readable candle line ("3 nến xoắn", "nến số 25",
/// "5 nến") from the raw personalization fields. Shared by the wizard
/// summary and every display site so the wording stays consistent.
///
/// Backward-compat: a legacy payload that has [candleCount] but no
/// [candleType] is treated as `regular`.
String? candleLabel({
  String? candleType,
  int? candleCount,
  int? candleNumber,
}) {
  final type = candleType ?? (candleCount != null ? CandleType.regular : null);
  switch (type) {
    case CandleType.number:
      if (candleNumber == null) return null;
      return 'nến số $candleNumber';
    case CandleType.spiral:
      if (candleCount == null) return null;
      return '$candleCount nến xoắn';
    case CandleType.regular:
      if (candleCount == null) return null;
      return '$candleCount nến';
    default:
      return null;
  }
}

/// Wizard payload — the keys here are the canonical JSON shape that ends
/// up in `OrderItem.personalization` on the backend.
class CakePersonalization {
  const CakePersonalization({
    this.textOnCake,
    this.candleType,
    this.candleCount,
    this.candleNumber,
    this.note,
  });

  factory CakePersonalization.fromMap(Map<String, dynamic> m) =>
      CakePersonalization(
        textOnCake: m['textOnCake'] as String?,
        candleType: m['candleType'] as String?,
        candleCount: (m['candleCount'] as num?)?.toInt(),
        candleNumber: (m['candleNumber'] as num?)?.toInt(),
        note: m['note'] as String?,
      );

  final String? textOnCake;

  /// One of [CandleType.regular] / [CandleType.number] /
  /// [CandleType.spiral]. Null = no candles.
  final String? candleType;

  /// Quantity — used for `regular` and `spiral`.
  final int? candleCount;

  /// Age/number to spell out with digit candles — used for `number`.
  final int? candleNumber;

  final String? note;

  bool get isEmpty =>
      (textOnCake == null || textOnCake!.isEmpty) &&
      candleType == null &&
      candleCount == null &&
      candleNumber == null &&
      (note == null || note!.isEmpty);

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    if (textOnCake != null && textOnCake!.isNotEmpty) {
      m['textOnCake'] = textOnCake;
    }
    if (candleType != null) m['candleType'] = candleType;
    if (candleCount != null) m['candleCount'] = candleCount;
    if (candleNumber != null) m['candleNumber'] = candleNumber;
    if (note != null && note!.isNotEmpty) m['note'] = note;
    return m;
  }

  /// Short human-readable summary for chips / order rows. Returns null
  /// when there's nothing to show.
  String? summarize() {
    final parts = <String>[];
    if (textOnCake != null && textOnCake!.isNotEmpty) {
      parts.add('"${textOnCake!}"');
    }
    final candle = candleLabel(
      candleType: candleType,
      candleCount: candleCount,
      candleNumber: candleNumber,
    );
    if (candle != null) parts.add(candle);
    if (note != null && note!.isNotEmpty) parts.add('ghi chú');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Bottom-sheet wizard for birthday-cake personalization. Returns the
/// finalised `CakePersonalization` on save, or null on dismiss.
class CakeWizardSheet extends StatefulWidget {
  const CakeWizardSheet({
    required this.productName,
    this.initial,
    super.key,
  });

  final String productName;
  final CakePersonalization? initial;

  @override
  State<CakeWizardSheet> createState() => _CakeWizardSheetState();
}

/// The four candle modes offered in the wizard. `null` selection = none.
enum _CandleMode { none, regular, number, spiral }

class _CakeWizardSheetState extends State<CakeWizardSheet> {
  late final TextEditingController _text;
  late final TextEditingController _note;

  /// Currently selected candle mode.
  _CandleMode _mode = _CandleMode.none;

  /// Quantity for regular/spiral candles (clamped 1–99).
  int _qty = 5;

  /// Age/number for digit candles (clamped 0–120).
  int _number = 25;

  /// Quick-pick quantities — the stepper still reaches any 1–99.
  static const List<int> _qtyPresets = [
    1, 2, 3, 5, 6, 7, 8, 9, 10, 12, 16, 18, 20, 21, 25, 30, 40, 50,
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? const CakePersonalization();
    _text = TextEditingController(text: init.textOnCake ?? '');
    _note = TextEditingController(text: init.note ?? '');

    // Resolve the mode from the loaded payload. Legacy payloads have a
    // candleCount but no candleType → treat as regular.
    final type = init.candleType ??
        (init.candleCount != null ? CandleType.regular : null);
    switch (type) {
      case CandleType.number:
        _mode = _CandleMode.number;
        _number = (init.candleNumber ?? 25).clamp(0, 120);
      case CandleType.spiral:
        _mode = _CandleMode.spiral;
        _qty = (init.candleCount ?? 5).clamp(1, 99);
      case CandleType.regular:
        _mode = _CandleMode.regular;
        _qty = (init.candleCount ?? 5).clamp(1, 99);
      default:
        _mode = _CandleMode.none;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: BananColors.primary,),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: Text(
                      'Cá nhân hoá: ${widget.productName}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.xs),
              Text(
                'Tất cả trường đều tuỳ chọn. Để trống các phần bạn không '
                'cần. Bánh sẽ làm theo mặc định.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: BananSpacing.lg),

              // Step 1 — text on cake
              TextField(
                controller: _text,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Chữ viết trên bánh',
                  hintText: 'vd: Chúc mừng sinh nhật An!',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),

              // Step 2 — candle picker: type selector + per-type controls
              const SizedBox(height: BananSpacing.sm),
              Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_outlined),
                        const SizedBox(width: BananSpacing.sm),
                        Text('Nến', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      'Loại nến',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in const [
                          (_CandleMode.none, 'Không nến'),
                          (_CandleMode.regular, 'Nến thường'),
                          (_CandleMode.number, 'Nến số'),
                          (_CandleMode.spiral, 'Nến xoắn'),
                        ])
                          ChoiceChip(
                            label: Text(entry.$2),
                            selected: _mode == entry.$1,
                            onSelected: (_) =>
                                setState(() => _mode = entry.$1),
                          ),
                      ],
                    ),

                    // Quantity controls for regular / spiral candles.
                    if (_mode == _CandleMode.regular ||
                        _mode == _CandleMode.spiral) ...[
                      const SizedBox(height: BananSpacing.md),
                      Row(
                        children: [
                          Icon(
                            _mode == _CandleMode.spiral
                                ? Icons.cyclone
                                : Icons.local_fire_department,
                            size: 18,
                            color: BananColors.primary,
                          ),
                          const SizedBox(width: BananSpacing.xs),
                          Text(
                            _mode == _CandleMode.spiral
                                ? 'Số nến xoắn'
                                : 'Số nến',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          _Stepper(
                            value: _qty,
                            min: 1,
                            max: 99,
                            onChanged: (v) => setState(() => _qty = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final n in _qtyPresets)
                            ChoiceChip(
                              label: Text('$n'),
                              selected: _qty == n,
                              onSelected: (_) => setState(() => _qty = n),
                            ),
                        ],
                      ),
                    ],

                    // Age input for number (digit) candles.
                    if (_mode == _CandleMode.number) ...[
                      const SizedBox(height: BananSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.tag,
                            size: 18,
                            color: BananColors.primary,
                          ),
                          const SizedBox(width: BananSpacing.xs),
                          Text('Số tuổi', style: theme.textTheme.bodyMedium),
                          const Spacer(),
                          _Stepper(
                            value: _number,
                            min: 0,
                            max: 120,
                            onChanged: (v) => setState(() => _number = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: BananSpacing.xs),
                      Text(
                        'Nến hình con số theo tuổi (vd: 25)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Step 3 — free-form note
              const SizedBox(height: BananSpacing.sm),
              TextField(
                controller: _note,
                maxLength: 240,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm cho thợ bánh',
                  hintText:
                      'vd: ribbon vàng, không sprinkles, kem ít ngọt …',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),

              const SizedBox(height: BananSpacing.lg),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Huỷ'),
                  ),
                  const Spacer(),
                  if (widget.initial != null && !widget.initial!.isEmpty)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pop(const CakePersonalization()),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Xoá cá nhân hoá'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () {
                      // Only carry the fields that apply to the chosen
                      // candle type; clear the rest so the payload stays
                      // unambiguous.
                      final String? candleType;
                      final int? candleCount;
                      final int? candleNumber;
                      switch (_mode) {
                        case _CandleMode.regular:
                          candleType = CandleType.regular;
                          candleCount = _qty;
                          candleNumber = null;
                        case _CandleMode.spiral:
                          candleType = CandleType.spiral;
                          candleCount = _qty;
                          candleNumber = null;
                        case _CandleMode.number:
                          candleType = CandleType.number;
                          candleCount = null;
                          candleNumber = _number;
                        case _CandleMode.none:
                          candleType = null;
                          candleCount = null;
                          candleNumber = null;
                      }
                      final value = CakePersonalization(
                        textOnCake: _text.text.trim().isEmpty
                            ? null
                            : _text.text.trim(),
                        candleType: candleType,
                        candleCount: candleCount,
                        candleNumber: candleNumber,
                        note: _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim(),
                      );
                      Navigator.of(context).pop(value);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact − / value / + stepper that lets any integer in [min]..[max]
/// be reached (so the candle quantity is never limited to presets).
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed:
                value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Giảm',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed:
                value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
            tooltip: 'Tăng',
          ),
        ],
      ),
    );
  }
}

/// Convenience helper — opens the bottom sheet and returns the wizard
/// result (null on dismiss).
Future<CakePersonalization?> showCakeWizard(
  BuildContext context, {
  required String productName,
  CakePersonalization? initial,
}) {
  return showModalBottomSheet<CakePersonalization?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CakeWizardSheet(
      productName: productName,
      initial: initial,
    ),
  );
}
