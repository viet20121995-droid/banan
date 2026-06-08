import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';
import '../reports_mgmt/xlsx_download.dart';

/// Merchant / admin view of the mailing list. Filter chips by status,
/// search by email/name, CSV export for piping into Mailchimp / Resend
/// Audiences. The list is read-only — no manual add (use the customer
/// footer to keep one canonical opt-in source) and no manual unsubscribe
/// (customer self-serves via the email footer link).
class NewsletterScreen extends ConsumerStatefulWidget {
  const NewsletterScreen({super.key});

  @override
  ConsumerState<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends ConsumerState<NewsletterScreen> {
  final _search = TextEditingController();
  bool? _confirmedFilter; // null = all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCompose() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ComposeNewsletterSheet(),
    );
  }

  Future<void> _downloadCsv() async {
    final res = await ref.read(newsletterApiProvider).exportCsv();
    if (!mounted) return;
    res.when(
      success: (bytes) async {
        await saveXlsx(
          bytes,
          'banan-newsletter-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải file CSV.')),
        );
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
    final async = ref.watch(_subscribersProvider((
      q: _search.text.trim(),
      confirmed: _confirmedFilter,
    )));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return MerchantShell(
      title: 'Newsletter',
      onRefresh: () async => ref.invalidate(_subscribersProvider),
      action: IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Xuất CSV',
        onPressed: _downloadCsv,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Soạn email'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_subscribersProvider),
        ),
        data: (page) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BananSpacing.lg,
                  BananSpacing.md,
                  BananSpacing.lg,
                  0,
                ),
                child: Wrap(
                  spacing: BananSpacing.md,
                  runSpacing: BananSpacing.sm,
                  children: [
                    _StatChip(
                      label: 'Đang nhận',
                      value: page.activeCount,
                      color: BananColors.success,
                    ),
                    _StatChip(
                      label: 'Chờ xác nhận',
                      value: page.pendingCount,
                      color: BananColors.gold,
                    ),
                    _StatChip(
                      label: 'Đã huỷ',
                      value: page.unsubscribedCount,
                      color: BananColors.cocoaSoft,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onSubmitted: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Tìm theo email hoặc tên',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: BananSpacing.md),
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _confirmedFilter == null,
                      onSelected: (_) =>
                          setState(() => _confirmedFilter = null),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('Đang nhận'),
                      selected: _confirmedFilter == true,
                      onSelected: (_) =>
                          setState(() => _confirmedFilter = true),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('Chờ'),
                      selected: _confirmedFilter == false,
                      onSelected: (_) =>
                          setState(() => _confirmedFilter = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: page.items.isEmpty
                    ? const EmptyState(
                        title: 'Chưa có đăng ký nào',
                        message:
                            'Khi khách đăng ký qua footer customer site, '
                            'họ sẽ hiện ở đây.',
                        icon: Icons.mail_outline,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BananSpacing.lg,
                        ),
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: BananSpacing.sm),
                        itemBuilder: (_, i) {
                          final s = page.items[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: BananSpacing.md,
                              vertical: BananSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BananRadii.rmd,
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: theme.dividerTheme.color ??
                                    Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.email,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                      Text(
                                        [
                                          if (s.fullName?.isNotEmpty ?? false)
                                            s.fullName!,
                                          'Nguồn: ${s.source ?? 'unknown'}',
                                          'Đăng ký ${df.format(s.subscribedAt.toLocal())}',
                                        ].join(' · '),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color:
                                              theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _StatusBadge(subscriber: s),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

typedef _Key = ({String q, bool? confirmed});

final _subscribersProvider =
    FutureProvider.autoDispose.family<SubscriberPage, _Key>((ref, key) async {
  final api = ref.watch(newsletterApiProvider);
  final res = await api.list(q: key.q, confirmed: key.confirmed);
  return res.when(
    success: (page) => page,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: BananSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.subscriber});
  final NewsletterSubscriber subscriber;

  @override
  Widget build(BuildContext context) {
    if (subscriber.unsubscribedAt != null) {
      return const StatusBadge(
        label: 'Đã huỷ',
        intent: StatusIntent.danger,
        dense: true,
      );
    }
    if (subscriber.confirmedAt == null) {
      return const StatusBadge(
        label: 'Chờ xác nhận',
        intent: StatusIntent.warning,
        dense: true,
      );
    }
    return const StatusBadge(
      label: 'Đang nhận',
      intent: StatusIntent.success,
      dense: true,
    );
  }
}

// ─── Compose newsletter ─────────────────────────────────────────────────

/// The three send audiences mirrored from the backend contract.
enum _Audience { subscribers, customers, both }

/// Bottom-sheet compose form: subject + body + audience + also-in-app
/// toggle, with a confirm step before firing a real send.
class _ComposeNewsletterSheet extends ConsumerStatefulWidget {
  const _ComposeNewsletterSheet();

  @override
  ConsumerState<_ComposeNewsletterSheet> createState() =>
      _ComposeNewsletterSheetState();
}

class _ComposeNewsletterSheetState
    extends ConsumerState<_ComposeNewsletterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  _Audience _audience = _Audience.both;
  bool _alsoInApp = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the "Gửi" enabled state as the user types.
    _subject.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _subject.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  String _audienceWire(_Audience a) => switch (a) {
        _Audience.subscribers => 'subscribers',
        _Audience.customers => 'customers',
        _Audience.both => 'both',
      };

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi email tới khách?'),
        content: const Text('Hành động này gửi thật.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final res = await ref.read(newsletterApiProvider).sendCampaign(
          subject: _subject.text.trim(),
          body: _body.text.trim(),
          audience: _audienceWire(_audience),
          alsoInApp: _alsoInApp,
        );
    if (!mounted) return;

    res.when(
      success: (r) {
        Navigator.pop(context); // close the compose sheet
        final inAppNote =
            _alsoInApp ? ' · ${r.inApp} thông báo in-app' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi ${r.emailsSent} email$inAppNote')),
        );
      },
      failure: (f) => setState(() {
        _sending = false;
        _error = 'Gửi thất bại: ${authFailureMessage(f)}';
      }),
    );
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
            Text('Soạn email', style: theme.textTheme.titleLarge),
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
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
              maxLength: 160,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nhập tiêu đề'
                  : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                hintText: 'Nội dung email gửi tới khách…',
                alignLabelWithHint: true,
              ),
              minLines: 5,
              maxLines: 10,
              maxLength: 5000,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập nội dung' : null,
            ),
            const SizedBox(height: BananSpacing.md),
            Text('Gửi tới', style: theme.textTheme.labelLarge),
            const SizedBox(height: BananSpacing.xs),
            SegmentedButton<_Audience>(
              segments: const [
                ButtonSegment(
                  value: _Audience.subscribers,
                  label: Text('Người đăng ký nhận tin'),
                ),
                ButtonSegment(
                  value: _Audience.customers,
                  label: Text('Tất cả khách hàng'),
                ),
                ButtonSegment(
                  value: _Audience.both,
                  label: Text('Cả hai'),
                ),
              ],
              selected: {_audience},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _audience = s.first),
            ),
            const SizedBox(height: BananSpacing.xs),
            Text(
              'Tất cả khách hàng = khách đã có tài khoản và đồng ý nhận tin '
              '(gồm khách cũ)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: BananSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gửi kèm thông báo trong app'),
              subtitle: Text(
                'Khách cũng nhận thông báo trong ứng dụng + push',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              value: _alsoInApp,
              onChanged: (v) => setState(() => _alsoInApp = v),
            ),
            const SizedBox(height: BananSpacing.md),
            FilledButton.icon(
              onPressed: (_sending || !_canSend) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Đang gửi…' : 'Gửi'),
            ),
          ],
        ),
      ),
    );
  }
}
