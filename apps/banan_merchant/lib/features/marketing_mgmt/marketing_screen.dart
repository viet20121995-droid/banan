// Map literals inside collection-for trip the trailing-comma lint.
// ignore_for_file: require_trailing_commas, curly_braces_in_flow_control_structures
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/read_only_banner.dart';
import '../../shared/shell/merchant_shell.dart';

/// Admin/owner control center for the 5 marketing programs. Each program
/// ships OFF; the admin flips it on + configures it here, and the customer
/// surfaces appear only when enabled.
class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});
  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  bool _loading = true;
  String? _err;

  // Referral
  bool _refOn = false;
  final _refReferrer = TextEditingController();
  final _refReferee = TextEditingController();
  final _refDesc = TextEditingController();
  // Gift card
  bool _gcOn = false;
  final _gcDenoms = TextEditingController();
  final _gcExpiry = TextEditingController();
  final _gcNote = TextEditingController();
  // Subscription
  bool _subOn = false;
  final _subNote = TextEditingController();
  final List<_Plan> _plans = [];
  // Catering
  bool _catOn = false;
  final _catMin = TextEditingController();
  final _catLead = TextEditingController();
  final _catDesc = TextEditingController();
  // Rewards
  bool _rwOn = false;
  final List<_Reward> _rewards = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _refReferrer, _refReferee, _refDesc,
      _gcDenoms, _gcExpiry, _gcNote,
      _subNote, _catMin, _catLead, _catDesc,
    ]) {
      c.dispose();
    }
    for (final p in _plans) p.dispose();
    for (final r in _rewards) r.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ref.read(marketingApiProvider).get();
    if (!mounted) return;
    res.when(
      success: (c) {
        _refOn = c.referral.enabled;
        _refReferrer.text = '${c.referral.numCfg('referrerPoints')}';
        _refReferee.text = '${c.referral.numCfg('refereePoints')}';
        _refDesc.text = c.referral.strCfg('description');

        _gcOn = c.giftCard.enabled;
        _gcDenoms.text =
            c.giftCard.listCfg('denominations').join(', ');
        _gcExpiry.text = '${c.giftCard.numCfg('expiryMonths', 12)}';
        _gcNote.text = c.giftCard.strCfg('note');

        _subOn = c.subscription.enabled;
        _subNote.text = c.subscription.strCfg('note');
        _plans
          ..clear()
          ..addAll(c.subscription.listCfg('plans').map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _Plan(
              m['name'] as String? ?? '',
              '${(m['priceVnd'] as num?) ?? ''}',
              m['period'] as String? ?? '',
            );
          }));

        _catOn = c.catering.enabled;
        _catMin.text = '${c.catering.numCfg('minGuests', 20)}';
        _catLead.text = '${c.catering.numCfg('leadDays', 3)}';
        _catDesc.text = c.catering.strCfg('description');

        _rwOn = c.rewards.enabled;
        _rewards
          ..clear()
          ..addAll(c.rewards.listCfg('items').map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _Reward(
              m['name'] as String? ?? '',
              '${(m['points'] as num?) ?? ''}',
            );
          }));

        setState(() => _loading = false);
      },
      failure: (f) => setState(() {
        _loading = false;
        _err = f.message ?? f.code;
      }),
    );
  }

  int _int(TextEditingController c, [int d = 0]) =>
      int.tryParse(c.text.trim()) ?? d;

  Future<void> _save(String label, Map<String, dynamic> patch) async {
    final res = await ref.read(marketingApiProvider).update(patch);
    if (!mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(marketingConfigProvider);
        _toast('Đã lưu $label');
      },
      failure: (f) => _toast('Lỗi: ${f.message ?? f.code}'),
    );
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// `merchant/marketing` lets ADMIN + MERCHANT_OWNER read the config, but
  /// `@Patch('config')` is @Roles(ADMIN). Without this an owner could fill the
  /// whole form in and only learn on save that it was never theirs to change.
  /// Assigned per-build; every `_section` below is built from within `build`.
  bool _canEdit = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MerchantShell(
        title: 'Chương trình Marketing',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    _canEdit =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;
    return MerchantShell(
      title: 'Chương trình Marketing',
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          if (!_canEdit)
            const ReadOnlyBanner(
              'Bạn xem được cấu hình này nhưng không sửa được — các chương '
              'trình marketing áp dụng cho toàn hệ thống nên chỉ quản trị '
              'viên (ADMIN) mới đổi được.',
            ),
          Text(
            'Mỗi chương trình mặc định TẮT (khách không thấy). Bật + cấu hình '
            'khi doanh nghiệp sẵn sàng triển khai.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.sm),
              child: Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: BananSpacing.md),
          _referralCard(),
          _giftCardCard(),
          _subscriptionCard(),
          _cateringCard(),
          _rewardsCard(),
          const SizedBox(height: BananSpacing.xxl),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
    required List<Widget> children,
    required VoidCallback onSave,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
                // Null disables both, so a non-admin can read the config but
                // can't start a change the backend will refuse.
                Switch(value: value, onChanged: _canEdit ? onToggle : null),
              ],
            ),
            const SizedBox(height: BananSpacing.sm),
            ...children,
            const SizedBox(height: BananSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _canEdit ? onSave : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);
  List<TextInputFormatter> get _digits =>
      [FilteringTextInputFormatter.digitsOnly];

  Widget _referralCard() => _section(
        title: 'Giới thiệu bạn bè (Referral)',
        subtitle: 'Khách giới thiệu qua mã / link, cả hai cùng nhận điểm.',
        value: _refOn,
        onToggle: (v) => setState(() => _refOn = v),
        onSave: () => _save('Giới thiệu', {
          'referralEnabled': _refOn,
          'referralConfig': {
            'referrerPoints': _int(_refReferrer),
            'refereePoints': _int(_refReferee),
            'description': _refDesc.text.trim(),
          },
        }),
        children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _refReferrer,
                    keyboardType: TextInputType.number,
                    inputFormatters: _digits,
                    decoration: _dec('Điểm cho người giới thiệu'))),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
                child: TextField(
                    controller: _refReferee,
                    keyboardType: TextInputType.number,
                    inputFormatters: _digits,
                    decoration: _dec('Điểm cho người được giới thiệu'))),
          ]),
          const SizedBox(height: BananSpacing.xs),
          TextField(
              controller: _refDesc,
              minLines: 2,
              maxLines: 4,
              decoration: _dec('Mô tả chương trình')),
        ],
      );

  Widget _giftCardCard() => _section(
        title: 'Thẻ quà tặng / E-voucher',
        subtitle: 'Định mệnh giá + hạn sử dụng.',
        value: _gcOn,
        onToggle: (v) => setState(() => _gcOn = v),
        onSave: () => _save('Thẻ quà tặng', {
          'giftCardEnabled': _gcOn,
          'giftCardConfig': {
            'denominations': _gcDenoms.text
                .split(RegExp(r'[,\s]+'))
                .map((s) => int.tryParse(s.trim()))
                .whereType<int>()
                .toList(),
            'expiryMonths': _int(_gcExpiry, 12),
            'note': _gcNote.text.trim(),
          },
        }),
        children: [
          TextField(
              controller: _gcDenoms,
              decoration: _dec('Mệnh giá (VND, cách nhau bởi dấu phẩy)')),
          const SizedBox(height: BananSpacing.xs),
          TextField(
              controller: _gcExpiry,
              keyboardType: TextInputType.number,
              inputFormatters: _digits,
              decoration: _dec('Hạn sử dụng (tháng)')),
          const SizedBox(height: BananSpacing.xs),
          TextField(
              controller: _gcNote, decoration: _dec('Ghi chú hiển thị')),
          const SizedBox(height: BananSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/gift-cards'),
              icon: const Icon(Icons.add_card, size: 18),
              label: const Text('Phát hành & quản lý thẻ'),
            ),
          ),
        ],
      );

  Widget _subscriptionCard() => _section(
        title: 'Gói định kỳ (Subscription)',
        subtitle: 'Khách nhận bánh tươi theo tuần/tháng.',
        value: _subOn,
        onToggle: (v) => setState(() => _subOn = v),
        onSave: () => _save('Gói định kỳ', {
          'subscriptionEnabled': _subOn,
          'subscriptionConfig': {
            'note': _subNote.text.trim(),
            'plans': [
              for (final p in _plans)
                if (p.name.text.trim().isNotEmpty)
                  {
                    'name': p.name.text.trim(),
                    'priceVnd': int.tryParse(p.price.text.trim()) ?? 0,
                    'period': p.period.text.trim(),
                  }
            ],
          },
        }),
        children: [
          TextField(controller: _subNote, decoration: _dec('Mô tả chung')),
          const SizedBox(height: BananSpacing.xs),
          for (var i = 0; i < _plans.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: TextField(
                        controller: _plans[i].name,
                        decoration: _dec('Tên gói'))),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: TextField(
                        controller: _plans[i].price,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits,
                        decoration: _dec('Giá'))),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: TextField(
                        controller: _plans[i].period,
                        decoration: _dec('Chu kỳ'))),
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _plans.removeAt(i).dispose())),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _plans.add(_Plan('', '', 'tháng'))),
              icon: const Icon(Icons.add),
              label: const Text('Thêm gói'),
            ),
          ),
        ],
      );

  Widget _cateringCard() => _section(
        title: 'Đặt tiệc / Sự kiện (Catering)',
        subtitle: 'Khách để lại thông tin, cửa hàng liên hệ tư vấn.',
        value: _catOn,
        onToggle: (v) => setState(() => _catOn = v),
        onSave: () => _save('Đặt tiệc', {
          'cateringEnabled': _catOn,
          'cateringConfig': {
            'minGuests': _int(_catMin, 20),
            'leadDays': _int(_catLead, 3),
            'description': _catDesc.text.trim(),
          },
        }),
        children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _catMin,
                    keyboardType: TextInputType.number,
                    inputFormatters: _digits,
                    decoration: _dec('Số khách tối thiểu'))),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
                child: TextField(
                    controller: _catLead,
                    keyboardType: TextInputType.number,
                    inputFormatters: _digits,
                    decoration: _dec('Đặt trước (ngày)'))),
          ]),
          const SizedBox(height: BananSpacing.xs),
          TextField(
              controller: _catDesc,
              minLines: 2,
              maxLines: 4,
              decoration: _dec('Mô tả dịch vụ')),
        ],
      );

  Widget _rewardsCard() => _section(
        title: 'Đổi điểm lấy quà (Rewards)',
        subtitle: 'Tự định nghĩa: bao nhiêu điểm đổi được gì.',
        value: _rwOn,
        onToggle: (v) => setState(() => _rwOn = v),
        onSave: () => _save('Đổi điểm', {
          'rewardsEnabled': _rwOn,
          'rewardsConfig': {
            'items': [
              for (final r in _rewards)
                if (r.name.text.trim().isNotEmpty)
                  {
                    'name': r.name.text.trim(),
                    'points': int.tryParse(r.points.text.trim()) ?? 0,
                  }
            ],
          },
        }),
        children: [
          for (var i = 0; i < _rewards.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: TextField(
                        controller: _rewards[i].name,
                        decoration: _dec('Phần quà'))),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: TextField(
                        controller: _rewards[i].points,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits,
                        decoration: _dec('Điểm'))),
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _rewards.removeAt(i).dispose())),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rewards.add(_Reward('', ''))),
              icon: const Icon(Icons.add),
              label: const Text('Thêm phần quà'),
            ),
          ),
        ],
      );
}

class _Plan {
  _Plan(String n, String p, String per)
      : name = TextEditingController(text: n),
        price = TextEditingController(text: p),
        period = TextEditingController(text: per);
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController period;
  void dispose() {
    name.dispose();
    price.dispose();
    period.dispose();
  }
}

class _Reward {
  _Reward(String n, String p)
      : name = TextEditingController(text: n),
        points = TextEditingController(text: p);
  final TextEditingController name;
  final TextEditingController points;
  void dispose() {
    name.dispose();
    points.dispose();
  }
}
