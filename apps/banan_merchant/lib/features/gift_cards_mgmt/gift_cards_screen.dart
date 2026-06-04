// ignore_for_file: require_trailing_commas
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

final _giftCardsProvider = FutureProvider.autoDispose<List<GiftCard>>((ref) async {
  final res = await ref.watch(giftCardsApiProvider).list();
  return res.when(success: (l) => l, failure: (f) => throw Exception(f.code));
});

/// Admin/owner: phát hành thẻ quà tặng (sinh mã) + xem danh sách + vô hiệu.
class GiftCardsScreen extends ConsumerStatefulWidget {
  const GiftCardsScreen({super.key});
  @override
  ConsumerState<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends ConsumerState<GiftCardsScreen> {
  final _value = TextEditingController();
  final _months = TextEditingController(text: '12');
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _months.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    final v = int.tryParse(_value.text.trim()) ?? 0;
    if (v < 1000) {
      _toast('Mệnh giá tối thiểu 1.000₫');
      return;
    }
    setState(() => _busy = true);
    final months = int.tryParse(_months.text.trim());
    final expiresAt = (months != null && months > 0)
        ? DateTime.now().add(Duration(days: months * 30)).toUtc().toIso8601String()
        : null;
    final res = await ref.read(giftCardsApiProvider).issue(
          valueVnd: v,
          expiresAt: expiresAt,
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (card) {
        _value.clear();
        _note.clear();
        ref.invalidate(_giftCardsProvider);
        _showCode(card);
      },
      failure: (f) => _toast('Lỗi: ${f.message ?? f.code}'),
    );
  }

  void _showCode(GiftCard card) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đã phát hành thẻ 🎁'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mã thẻ (đưa cho khách):'),
            const SizedBox(height: 8),
            SelectableText(
              card.code,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Text('Mệnh giá: ${_fmt.format(card.initialVnd)}'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: card.code));
              _toast('Đã sao chép mã');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
        ],
      ),
    );
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(_giftCardsProvider);
    return MerchantShell(
      title: 'Thẻ quà tặng',
      onRefresh: () async => ref.invalidate(_giftCardsProvider),
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(BananSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Phát hành thẻ mới', style: theme.textTheme.titleMedium),
                  const SizedBox(height: BananSpacing.sm),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _value,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Mệnh giá (VND)'),
                      ),
                    ),
                    const SizedBox(width: BananSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _months,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Hạn dùng (tháng)'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: BananSpacing.xs),
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  const SizedBox(height: BananSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _issue,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_card),
                      label: Text(_busy ? 'Đang tạo…' : 'Phát hành (sinh mã)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          Text('Đã phát hành', style: theme.textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Lỗi: $e'),
            data: (cards) => cards.isEmpty
                ? Text('Chưa có thẻ nào.', style: theme.textTheme.bodyMedium)
                : Column(
                    children: [
                      for (final c in cards)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              c.isActive
                                  ? Icons.card_giftcard
                                  : Icons.block,
                              color: c.isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            title: SelectableText(c.code),
                            subtitle: Text(
                              'Số dư ${_fmt.format(c.balanceVnd)} / '
                              '${_fmt.format(c.initialVnd)}'
                              '${c.isActive ? '' : ' · đã khoá'}',
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(giftCardsApiProvider)
                                    .deactivate(c.id);
                                ref.invalidate(_giftCardsProvider);
                              },
                              child: Text(c.isActive ? 'Khoá' : 'Mở'),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: BananSpacing.xxl),
        ],
      ),
    );
  }
}
