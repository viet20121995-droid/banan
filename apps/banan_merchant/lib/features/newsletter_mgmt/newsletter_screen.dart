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
