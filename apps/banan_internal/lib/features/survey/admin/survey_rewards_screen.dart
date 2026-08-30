import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/internal_api.dart';
import '../../../data/survey_models.dart';
import '../../../shared/widgets.dart';
import 'survey_shell.dart';

/// Reward foundation — campaigns ship DISABLED; the counter screen redeems
/// voucher codes and shows the claim history.
class SurveyRewardsScreen extends ConsumerStatefulWidget {
  const SurveyRewardsScreen({super.key});

  @override
  ConsumerState<SurveyRewardsScreen> createState() => _SurveyRewardsScreenState();
}

class _SurveyRewardsScreenState extends ConsumerState<SurveyRewardsScreen> {
  Result<List<SurveyCampaignView>, AppFailure>? _campaigns;
  List<SurveyClaimView> _claims = const [];
  final _redeemCode = TextEditingController();
  SurveyRedeemResult? _redeemed;
  String? _redeemError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _redeemCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _campaigns = null);
    final api = ref.read(internalApiProvider);
    final res = await api.surveyCampaigns();
    final claims = await api.surveyClaims();
    if (!mounted) return;
    setState(() {
      _campaigns = res;
      claims.when(success: (c) => _claims = c, failure: (_) {});
    });
  }

  Future<void> _redeem() async {
    final code = _redeemCode.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _redeemed = null;
      _redeemError = null;
    });
    final res = await ref.read(internalApiProvider).surveyRedeem(code);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (r) {
        setState(() {
          _redeemed = r;
          _redeemCode.clear();
        });
        _load();
      },
      failure: (f) => setState(() => _redeemError = f.message ?? 'Không đổi được mã.'),
    );
  }

  Future<void> _editCampaign(SurveyCampaignView? c) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CampaignDialog(campaign: c),
    );
    if (body == null) return;
    final api = ref.read(internalApiProvider);
    final res = c == null
        ? await api.surveyCreateCampaign(body)
        : await api.surveyUpdateCampaign(c.id, body);
    if (!mounted) return;
    res.when(success: (_) => _load(), failure: (f) => showFailure(context, f));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurveyShell(
      title: 'Quà tặng khảo sát',
      subtitle: 'Mặc định TẮT — bật khi sẵn sàng tặng quà',
      body: FetchBody<List<SurveyCampaignView>>(
        state: _campaigns,
        onRetry: _load,
        builder: (campaigns) => ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Wrap(
              spacing: BananSpacing.md,
              runSpacing: BananSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('Chương trình', style: theme.textTheme.titleMedium),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo chương trình'),
                  onPressed: () => _editCampaign(null),
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.md),
            if (campaigns.isEmpty)
              const Text('Chưa có chương trình quà nào — khảo sát vẫn chạy bình thường.'),
            for (final c in campaigns) _campaignCard(c),
            const SizedBox(height: BananSpacing.xl),
            Text('Đổi quà tại quầy', style: theme.textTheme.titleMedium),
            const SizedBox(height: BananSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _redeemCode,
                    decoration: const InputDecoration(
                      labelText: 'Nhập mã quà (BAN-…)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _redeem(),
                  ),
                ),
                const SizedBox(width: BananSpacing.md),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _redeem,
                    child: const Text('Xác nhận đổi'),
                  ),
                ),
              ],
            ),
            if (_redeemError != null)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.sm),
                child: Text(_redeemError!,
                    style: TextStyle(color: theme.colorScheme.error),),
              ),
            if (_redeemed != null)
              Card(
                margin: const EdgeInsets.only(top: BananSpacing.md),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  title: Text('Đã đổi ${_redeemed!.voucherCode} · ${_redeemed!.campaignName}'),
                  subtitle: Text(
                    'Khảo sát tại ${_redeemed!.storeName}'
                    '${_redeemed!.issuedAt != null ? ' · phát lúc ${vnDateTime.format(_redeemed!.issuedAt!.toLocal())}' : ''}',
                  ),
                ),
              ),
            const SizedBox(height: BananSpacing.xl),
            Text('Lịch sử quà', style: theme.textTheme.titleMedium),
            const SizedBox(height: BananSpacing.md),
            if (_claims.isEmpty) const Text('Chưa phát quà nào.'),
            for (final cl in _claims)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cl.voucherCode ?? '(quà lời nhắn)'),
                subtitle: Text(
                  '${cl.campaignName} · ${cl.storeName}'
                  '${cl.issuedAt != null ? ' · ${vnDateTime.format(cl.issuedAt!.toLocal())}' : ''}',
                ),
                trailing: StatusBadge(
                  label: switch (cl.status) {
                    'ISSUED' => 'Đã phát',
                    'REDEEMED' => 'Đã đổi',
                    'EXPIRED' => 'Hết hạn',
                    'VOID' => 'Đã hủy',
                    _ => cl.status,
                  },
                  intent: switch (cl.status) {
                    'REDEEMED' => StatusIntent.success,
                    'ISSUED' => StatusIntent.info,
                    _ => StatusIntent.neutral,
                  },
                  dense: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campaignCard(SurveyCampaignView c) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.name, style: theme.textTheme.titleSmall)),
                StatusBadge(
                  label: c.isEnabled ? 'ĐANG BẬT' : 'Đang tắt',
                  intent: c.isEnabled ? StatusIntent.success : StatusIntent.neutral,
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.xs),
            Text(
              [
                switch (c.mode) {
                  'MESSAGE_ONLY' => 'Lời nhắn',
                  'VOUCHER_CODE' => 'Mã voucher',
                  _ => 'Chưa chọn loại',
                },
                'trúng ${c.probabilityPct}%',
                'hạn ${c.expiryDays} ngày',
                if (c.dailyCap != null) 'tối đa ${c.dailyCap}/ngày',
                if (c.totalCap != null) 'tổng ${c.issuedCount}/${c.totalCap}'
                else 'đã phát ${c.issuedCount}',
                'đã đổi ${c.redeemedCount}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (c.description != null)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.xs),
                child: Text(c.description!, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: BananSpacing.sm),
            Wrap(
              spacing: BananSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () => _editCampaign(c),
                  child: const Text('Cấu hình'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final api = ref.read(internalApiProvider);
                    final res =
                        await api.surveyUpdateCampaign(c.id, {'isEnabled': !c.isEnabled});
                    if (!mounted) return;
                    if (res.isSuccess) {
                      await _load();
                    } else if (context.mounted) {
                      // Surface the real reason (e.g. another campaign is on).
                      res.when(success: (_) {}, failure: (f) => showFailure(context, f));
                    }
                  },
                  child: Text(c.isEnabled ? 'Tắt' : 'Bật'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({this.campaign});
  final SurveyCampaignView? campaign;

  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  late final _name = TextEditingController(text: widget.campaign?.name ?? '');
  late final _description = TextEditingController(text: widget.campaign?.description ?? '');
  late final _instructions = TextEditingController(text: widget.campaign?.instructions ?? '');
  late final _expiryDays =
      TextEditingController(text: '${widget.campaign?.expiryDays ?? 7}');
  late final _probability =
      TextEditingController(text: '${widget.campaign?.probabilityPct ?? 100}');
  late final _dailyCap =
      TextEditingController(text: widget.campaign?.dailyCap?.toString() ?? '');
  late final _totalCap =
      TextEditingController(text: widget.campaign?.totalCap?.toString() ?? '');
  late String _mode = widget.campaign?.mode ?? 'MESSAGE_ONLY';
  late DateTime? _startsAt = widget.campaign?.startsAt;
  late DateTime? _endsAt = widget.campaign?.endsAt;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name, _description, _instructions, _expiryDays, _probability, _dailyCap, _totalCap,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _startsAt : _endsAt) ?? DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => start ? _startsAt = picked : _endsAt = picked);
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Cần tên quà.');
      return;
    }
    final expiry = int.tryParse(_expiryDays.text);
    final prob = int.tryParse(_probability.text);
    if (expiry == null || expiry < 1 || prob == null || prob < 0 || prob > 100) {
      setState(() => _error = 'Hạn dùng ≥ 1 ngày, xác suất 0–100.');
      return;
    }
    // Blank cap = no cap (sent as null to CLEAR a stored value); anything
    // else must be a real positive number — never silently dropped.
    final dailyCap = _dailyCap.text.trim().isEmpty ? null : int.tryParse(_dailyCap.text);
    final totalCap = _totalCap.text.trim().isEmpty ? null : int.tryParse(_totalCap.text);
    if ((_dailyCap.text.trim().isNotEmpty && (dailyCap == null || dailyCap < 1)) ||
        (_totalCap.text.trim().isNotEmpty && (totalCap == null || totalCap < 1))) {
      setState(() => _error = 'Giới hạn phải là số ≥ 1 (hoặc để trống).');
      return;
    }
    if (_startsAt != null && _endsAt != null && _startsAt!.isAfter(_endsAt!)) {
      setState(() => _error = 'Ngày bắt đầu phải trước ngày kết thúc.');
      return;
    }
    // Explicit nulls so clearing a field actually clears it server-side.
    Navigator.of(context).pop(<String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'instructions': _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      'mode': _mode,
      'expiryDays': expiry,
      'probabilityPct': prob,
      'dailyCap': dailyCap,
      'totalCap': totalCap,
      'startsAt': _startsAt?.toIso8601String(),
      'endsAt': _endsAt?.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.campaign == null ? 'Tạo chương trình quà' : 'Cấu hình quà'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Tên quà',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(
                  labelText: 'Hình thức',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('Không quà')),
                  DropdownMenuItem(value: 'MESSAGE_ONLY', child: Text('Lời nhắn cảm ơn')),
                  DropdownMenuItem(value: 'VOUCHER_CODE', child: Text('Mã voucher')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Mô tả quà (khách thấy sau khi gửi)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: _instructions,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Hướng dẫn nhận quà',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text(_startsAt == null
                          ? 'Bắt đầu (tùy chọn)'
                          : 'Từ ${vnDate.format(_startsAt!)}',),
                    ),
                  ),
                  if (_startsAt != null)
                    IconButton(
                      tooltip: 'Bỏ ngày bắt đầu',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _startsAt = null),
                    ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text(
                          _endsAt == null ? 'Kết thúc (tùy chọn)' : 'Đến ${vnDate.format(_endsAt!)}',),
                    ),
                  ),
                  if (_endsAt != null)
                    IconButton(
                      tooltip: 'Bỏ ngày kết thúc',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _endsAt = null),
                    ),
                ],
              ),
              const SizedBox(height: BananSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hạn dùng (ngày)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _probability,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Xác suất trúng (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dailyCap,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giới hạn/ngày (trống = không)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _totalCap,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tổng giới hạn (trống = không)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: BananSpacing.md),
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
