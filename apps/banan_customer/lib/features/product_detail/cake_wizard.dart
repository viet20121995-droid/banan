import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Wizard payload — the keys here are the canonical JSON shape that ends
/// up in `OrderItem.personalization` on the backend.
class CakePersonalization {
  const CakePersonalization({
    this.textOnCake,
    this.candleCount,
    this.note,
  });

  factory CakePersonalization.fromMap(Map<String, dynamic> m) =>
      CakePersonalization(
        textOnCake: m['textOnCake'] as String?,
        candleCount: (m['candleCount'] as num?)?.toInt(),
        note: m['note'] as String?,
      );

  final String? textOnCake;
  final int? candleCount;
  final String? note;

  bool get isEmpty =>
      (textOnCake == null || textOnCake!.isEmpty) &&
      candleCount == null &&
      (note == null || note!.isEmpty);

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    if (textOnCake != null && textOnCake!.isNotEmpty) {
      m['textOnCake'] = textOnCake;
    }
    if (candleCount != null) m['candleCount'] = candleCount;
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
    if (candleCount != null) parts.add('$candleCount nến');
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

class _CakeWizardSheetState extends State<CakeWizardSheet> {
  late final TextEditingController _text;
  late final TextEditingController _note;
  int? _candleCount;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? const CakePersonalization();
    _text = TextEditingController(text: init.textOnCake ?? '');
    _note = TextEditingController(text: init.note ?? '');
    _candleCount = init.candleCount;
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
                      color: BananColors.primary),
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
                'cần — bánh sẽ làm theo mặc định.',
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

              // Step 2 — candle count picker (stepper + chip presets)
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
                        Text('Số nến',
                            style: theme.textTheme.titleSmall),
                        const Spacer(),
                        if (_candleCount != null)
                          Text(
                            '$_candleCount',
                            style: theme.textTheme.titleLarge,
                          ),
                      ],
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Không nến'),
                          selected: _candleCount == null,
                          onSelected: (_) =>
                              setState(() => _candleCount = null),
                        ),
                        for (final n in const [1, 3, 5, 7, 10, 18, 21, 30])
                          ChoiceChip(
                            label: Text('$n'),
                            selected: _candleCount == n,
                            onSelected: (_) =>
                                setState(() => _candleCount = n),
                          ),
                      ],
                    ),
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
                      final value = CakePersonalization(
                        textOnCake: _text.text.trim().isEmpty
                            ? null
                            : _text.text.trim(),
                        candleCount: _candleCount,
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
