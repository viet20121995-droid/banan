import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/cover_image_picker.dart';
import '../../shared/shell/merchant_shell.dart';
import '../reports_mgmt/xlsx_download.dart';

/// Merchant / admin view of the mailing list + email campaigns.
///
/// Two tabs:
///  - **Người đăng ký** — the opt-in list (filter by status, search,
///    CSV export). Read-only — opt-in is sourced from the customer footer,
///    unsubscribe is self-serve via the email footer link.
///  - **Đã gửi** — history of sent campaigns, with a tap-to-preview of the
///    exact email that went out.
///
/// The "Soạn email" FAB opens a full composer with a header image, live
/// preview, a test-send-to-myself, audience picker and an optional in-app
/// broadcast.
class NewsletterScreen extends ConsumerStatefulWidget {
  const NewsletterScreen({super.key});

  @override
  ConsumerState<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends ConsumerState<NewsletterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _search = TextEditingController();
  bool? _confirmedFilter; // null = all

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCompose() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ComposeNewsletterSheet(),
    );
    if (!mounted) return;
    // A send records a campaign — refresh the history tab.
    ref.invalidate(_campaignsProvider);
  }

  Future<void> _downloadCsv() async {
    final res = await ref.read(newsletterApiProvider).exportCsv();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await res.when(
      success: (bytes) async {
        await saveXlsx(
          bytes,
          'banan-newsletter-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã tải file CSV.')),
        );
      },
      failure: (f) async {
        messenger.showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MerchantShell(
      title: 'Newsletter',
      onRefresh: () async {
        ref
          ..invalidate(_subscribersProvider)
          ..invalidate(_campaignsProvider);
      },
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Người đăng ký'),
                Tab(text: 'Đã gửi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _subscribersTab(theme),
                const _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscribersTab(ThemeData theme) {
    final key = (
      q: _search.text.trim(),
      confirmed: _confirmedFilter,
    );
    final async = ref.watch(_subscribersProvider(key));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return async.when(
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
                    onSelected: (_) => setState(() => _confirmedFilter = null),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('Đang nhận'),
                    selected: _confirmedFilter ?? false,
                    onSelected: (_) => setState(() => _confirmedFilter = true),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('Chờ'),
                    selected: _confirmedFilter == false,
                    onSelected: (_) => setState(() => _confirmedFilter = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: page.items.isEmpty
                  ? const EmptyState(
                      title: 'Chưa có đăng ký nào',
                      message: 'Khi khách đăng ký qua footer customer site, '
                          'họ sẽ hiện ở đây.',
                      icon: Icons.mail_outline,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        BananSpacing.lg,
                        0,
                        BananSpacing.lg,
                        BananSpacing.lg,
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
                              color: theme.dividerTheme.color ?? Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: theme.colorScheme.outline,
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

final _campaignsProvider =
    FutureProvider.autoDispose<List<NewsletterCampaign>>((ref) async {
  final api = ref.watch(newsletterApiProvider);
  final res = await api.listCampaigns();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Human label for the `subscribers | customers | both` wire value.
String audienceLabel(String wire) => switch (wire) {
      'subscribers' => 'Người đăng ký nhận tin',
      'customers' => 'Tất cả khách hàng',
      'both' => 'Cả hai',
      _ => wire,
    };

// ─── History tab ────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(_campaignsProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(_campaignsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Chưa gửi email nào',
            message: 'Nhấn "Soạn email" để gửi bản tin đầu tiên. '
                'Mỗi lần gửi sẽ được lưu lại ở đây.',
            icon: Icons.mark_email_read_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(BananSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.sm),
          itemBuilder: (_, i) {
            final c = items[i];
            return InkWell(
              borderRadius: BananRadii.rmd,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _CampaignDetailDialog(campaign: c),
              ),
              child: Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.black12,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BananRadii.rsm,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Image.network(
                            c.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: BananColors.surfaceDim,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 18,
                                color: BananColors.cocoaSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: BananSpacing.md),
                    ] else ...[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          borderRadius: BananRadii.rsm,
                          color: BananColors.surfaceDim,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.mail_outline,
                          color: BananColors.cocoaSoft,
                        ),
                      ),
                      const SizedBox(width: BananSpacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.subject,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.body.replaceAll('\n', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: BananSpacing.xs),
                          Wrap(
                            spacing: BananSpacing.sm,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MetaPill(
                                icon: Icons.group_outlined,
                                label: audienceLabel(c.audience),
                              ),
                              _MetaPill(
                                icon: Icons.mark_email_read_outlined,
                                label: '${c.emailsSent}/${c.recipients} email',
                              ),
                              if (c.alsoInApp)
                                _MetaPill(
                                  icon: Icons.notifications_active_outlined,
                                  label: '${c.inAppSent} in-app',
                                ),
                              _MetaPill(
                                icon: Icons.schedule,
                                label: df.format(c.createdAt.toLocal()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black26),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

/// Read-only detail for a past campaign — shows the exact email preview plus
/// delivery stats.
class _CampaignDetailDialog extends StatelessWidget {
  const _CampaignDetailDialog({required this.campaign});
  final NewsletterCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                BananSpacing.lg,
                BananSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chi tiết bản tin',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BananSpacing.lg),
              child: Wrap(
                spacing: BananSpacing.sm,
                runSpacing: 4,
                children: [
                  _MetaPill(
                    icon: Icons.group_outlined,
                    label: audienceLabel(campaign.audience),
                  ),
                  _MetaPill(
                    icon: Icons.mark_email_read_outlined,
                    label: '${campaign.emailsSent}/${campaign.recipients} email',
                  ),
                  if (campaign.alsoInApp)
                    _MetaPill(
                      icon: Icons.notifications_active_outlined,
                      label: '${campaign.inAppSent} in-app',
                    ),
                  _MetaPill(
                    icon: Icons.schedule,
                    label: df.format(campaign.createdAt.toLocal()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: EmailPreview(
                  subject: campaign.subject,
                  body: campaign.body,
                  imageUrl: campaign.imageUrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A faithful, branded preview of the email as the customer will see it —
/// shared by the composer's live preview and the history detail.
class EmailPreview extends StatelessWidget {
  const EmailPreview({
    required this.subject,
    required this.body,
    this.imageUrl,
    super.key,
  });
  final String subject;
  final String body;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              color: const Color(0xFFC9405C),
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BananRadii.rsm,
              child: Image.network(
                imageUrl!.trim(),
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: BananColors.surfaceDim,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: BananColors.cocoaSoft,
                  ),
                ),
              ),
            ),
            const SizedBox(height: BananSpacing.md),
          ],
          Text(
            subject.isEmpty ? 'Tiêu đề email' : subject,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1E6A35),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(
            body.isEmpty ? 'Nội dung email…' : body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF2B2A22),
              height: 1.5,
            ),
          ),
          const SizedBox(height: BananSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: BananSpacing.sm),
          Text(
            'Bạn nhận được email này vì đã đăng ký nhận tin từ Banan. '
            'Mỗi email đều kèm liên kết huỷ nhận.',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

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

/// Bottom-sheet compose form: header image + subject + body + live preview +
/// test-send + audience + also-in-app toggle, with a confirm step before
/// firing a real send.
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
  String? _imageUrl;
  _Audience _audience = _Audience.both;
  bool _alsoInApp = true;
  bool _showPreview = false;
  bool _sending = false;
  bool _testing = false;
  String? _error;
  String _lastTestEmail = '';

  @override
  void initState() {
    super.initState();
    // Re-evaluate the "Gửi" enabled state + preview as the user types.
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

  Future<void> _sendTest() async {
    if (!_canSend) return;
    final email = await _askTestEmail();
    if (email == null || !mounted) return;

    setState(() {
      _testing = true;
      _error = null;
    });
    final res = await ref.read(newsletterApiProvider).sendTest(
          subject: _subject.text.trim(),
          body: _body.text.trim(),
          testEmail: email,
          imageUrl: _imageUrl,
        );
    if (!mounted) return;
    setState(() => _testing = false);
    res.when(
      success: (_) {
        _lastTestEmail = email;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi email thử tới $email')),
        );
      },
      failure: (f) => setState(
        () => _error = 'Gửi thử thất bại: ${authFailureMessage(f)}',
      ),
    );
  }

  Future<String?> _askTestEmail() async {
    final ctrl = TextEditingController(text: _lastTestEmail);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi email thử'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email nhận thử',
              hintText: 'vd: ban@banancakes.vn',
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Nhập email';
              if (!s.contains('@') || !s.contains('.')) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Gửi thử'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi email tới khách?'),
        content: Text(
          'Gửi thật tới: ${switch (_audience) {
            _Audience.subscribers => 'người đăng ký nhận tin',
            _Audience.customers => 'tất cả khách hàng (gồm khách cũ)',
            _Audience.both => 'người đăng ký + tất cả khách hàng',
          }}.'
          '${_alsoInApp ? '\nKèm thông báo trong app + push.' : ''}',
        ),
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
          imageUrl: _imageUrl,
          alsoInApp: _alsoInApp,
        );
    if (!mounted) return;

    res.when(
      success: (r) {
        Navigator.pop(context, true); // close the compose sheet
        final inAppNote = _alsoInApp ? ' · ${r.inApp} thông báo in-app' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi ${r.emailsSent}/${r.recipients} email$inAppNote'),
          ),
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
    final busy = _sending || _testing;
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
            CoverImagePicker(
              url: _imageUrl,
              onChanged: (v) => setState(() => _imageUrl = v),
              label: 'Ảnh tiêu đề (tuỳ chọn)',
              helperText: 'Hiển thị ở đầu email gửi tới khách.',
              recommendedSize: '1200×480px (tỉ lệ 5:2)',
            ),
            const SizedBox(height: BananSpacing.md),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
              maxLength: 160,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
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
            const SizedBox(height: BananSpacing.xs),
            // Live preview toggle — see exactly what the customer receives.
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                  icon: Icon(
                    _showPreview
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(_showPreview ? 'Ẩn xem trước' : 'Xem trước'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: (busy || !_canSend) ? null : _sendTest,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.outgoing_mail, size: 18),
                  label: const Text('Gửi thử'),
                ),
              ],
            ),
            if (_showPreview) ...[
              const SizedBox(height: BananSpacing.sm),
              EmailPreview(
                subject: _subject.text.trim(),
                body: _body.text.trim(),
                imageUrl: _imageUrl,
              ),
            ],
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
              onSelectionChanged: (s) => setState(() => _audience = s.first),
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
              onPressed: (busy || !_canSend) ? null : _send,
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
