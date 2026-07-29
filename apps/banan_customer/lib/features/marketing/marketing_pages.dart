// Config-driven builders use map literals + nested widgets; the trailing-
// comma / const lints add noise without value here.
// ignore_for_file: require_trailing_commas, prefer_const_constructors
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

/// Shared scaffold: shows a "chương trình chưa mở" empty state when the
/// program is disabled (so a stray deep-link is graceful), else the content.
class _ProgramScaffold extends ConsumerWidget {
  const _ProgramScaffold({
    required this.title,
    required this.enabled,
    required this.builder,
  });
  final String title;
  final bool Function(MarketingConfig) enabled;
  final Widget Function(BuildContext, MarketingConfig) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketingConfigProvider);
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.loadFailed)),
        data: (cfg) => enabled(cfg)
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: builder(context, cfg),
                ),
              )
            : EmptyState(
                title: s.programNotOpen,
                message: s.programNotOpenMsg,
                icon: Icons.lock_clock_outlined,
              ),
      ),
    );
  }
}

// ── Referral ───────────────────────────────────────────────────────────────
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  String _code(String userId) =>
      'BANAN-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final s = ref.watch(stringsProvider);
    return _ProgramScaffold(
      title: s.referralTitle,
      enabled: (c) => c.referral.enabled,
      builder: (context, c) {
        final theme = Theme.of(context);
        if (session == null) {
          return _LoginPrompt(message: s.referralLoginPrompt);
        }
        final code = _code(session.user.id);
        final link = '${Uri.base.origin}/?ref=$code';
        final referrer = c.referral.numCfg('referrerPoints').toInt();
        final referee = c.referral.numCfg('refereePoints').toInt();
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text(s.referralTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: BananSpacing.sm),
            Text(c.referral.strCfg('description'),
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: BananSpacing.lg),
            if (referrer > 0 || referee > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  child: Text(
                    s.referralBonus(referrer, referee),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: BananSpacing.md),
            _CopyTile(label: s.referralCodeLabel, value: code),
            const SizedBox(height: BananSpacing.sm),
            _CopyTile(label: s.shareLinkLabel, value: link),
          ],
        );
      },
    );
  }
}

// ── Gift cards ───────────────────────────────────────────────────────────────
class GiftCardScreen extends ConsumerWidget {
  const GiftCardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _ProgramScaffold(
      title: s.giftCardTitle,
      enabled: (c) => c.giftCard.enabled,
      builder: (context, c) {
        final theme = Theme.of(context);
        final denoms = c.giftCard
            .listCfg('denominations')
            .map((e) => (e as num).toDouble())
            .toList();
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text(s.giftCardHeading, style: theme.textTheme.headlineMedium),
            const SizedBox(height: BananSpacing.sm),
            Text(c.giftCard.strCfg('note'), style: theme.textTheme.bodyLarge),
            const SizedBox(height: BananSpacing.lg),
            Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.sm,
              children: [
                for (final d in denoms)
                  Chip(
                    label: Text(_fmt.format(d)),
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
              ],
            ),
            const SizedBox(height: BananSpacing.md),
            Text(s.giftCardExpiry(c.giftCard.numCfg('expiryMonths', 12).toInt()),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: BananSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push('/contact'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(s.contactToBuyGiftCard),
            ),
          ],
        );
      },
    );
  }
}

// ── Subscription ─────────────────────────────────────────────────────────────
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _ProgramScaffold(
      title: s.subscriptionTitle,
      enabled: (c) => c.subscription.enabled,
      builder: (context, c) {
        final theme = Theme.of(context);
        final plans = c.subscription.listCfg('plans');
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text(s.subscriptionHeading, style: theme.textTheme.headlineMedium),
            const SizedBox(height: BananSpacing.sm),
            Text(c.subscription.strCfg('note'),
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: BananSpacing.lg),
            for (final p in plans)
              Builder(builder: (_) {
                final m = (p as Map).cast<String, dynamic>();
                return Card(
                  child: ListTile(
                    title: Text(m['name'] as String? ?? ''),
                    subtitle: Text(s.perPeriod('${m['period'] ?? ''}')),
                    trailing: Text(
                      _fmt.format(((m['priceVnd'] as num?) ?? 0).toDouble()),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                );
              }),
            const SizedBox(height: BananSpacing.md),
            FilledButton.icon(
              onPressed: () => context.push('/contact'),
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text(s.contactToSubscribe),
            ),
          ],
        );
      },
    );
  }
}

// ── Catering (functional contact form) ───────────────────────────────────────
class CateringScreen extends ConsumerStatefulWidget {
  const CateringScreen({super.key});
  @override
  ConsumerState<CateringScreen> createState() => _CateringScreenState();
}

class _CateringScreenState extends ConsumerState<CateringScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _detail = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _sent = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _detail.text.trim().length < 5) {
      setState(
        () => _msg = ref.read(stringsProvider).fillNamePhoneContent,
      );
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final res = await ref.read(contactApiProvider).submit(
          name: _name.text.trim(),
          email: _email.text.trim().isEmpty
              ? 'catering@guest.banan.local'
              : _email.text.trim(),
          phone: _phone.text.trim(),
          subject: 'Đặt tiệc / Catering',
          message: _detail.text.trim(),
        );
    if (!mounted) return;
    res.when(
      success: (_) => setState(() {
        _busy = false;
        _sent = true;
      }),
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return _ProgramScaffold(
      title: s.cateringTitle,
      enabled: (c) => c.catering.enabled,
      builder: (context, c) {
        final theme = Theme.of(context);
        if (_sent) {
          return EmptyState(
            title: s.cateringSentTitle,
            message: s.cateringSentMsg,
            icon: Icons.check_circle_outline,
          );
        }
        final minG = c.catering.numCfg('minGuests', 20).toInt();
        final lead = c.catering.numCfg('leadDays', 3).toInt();
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text(s.cateringHeading, style: theme.textTheme.headlineMedium),
            const SizedBox(height: BananSpacing.sm),
            Text(c.catering.strCfg('description'),
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: BananSpacing.xs),
            Text(s.cateringMinLead(minG, lead),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: BananSpacing.lg),
            TextField(controller: _name, decoration: InputDecoration(labelText: s.nameReq)),
            const SizedBox(height: BananSpacing.sm),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: s.phoneReq)),
            const SizedBox(height: BananSpacing.sm),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.emailOptionalLabel)),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _detail,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: s.messageReq,
                hintText: s.contentHintCatering,
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: BananSpacing.sm),
              Text(_msg!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: BananSpacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_busy ? s.sending : s.sendRequest),
            ),
          ],
        );
      },
    );
  }
}

// ── Rewards (đổi điểm) ───────────────────────────────────────────────────────
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final s = ref.watch(stringsProvider);
    return _ProgramScaffold(
      title: s.rewardsTitle,
      enabled: (c) => c.rewards.enabled,
      builder: (context, c) {
        final theme = Theme.of(context);
        final items = c.rewards.listCfg('items');
        final balance = session?.user.pointsBalance;
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text(s.rewardsTitle, style: theme.textTheme.headlineMedium),
            if (balance != null) ...[
              const SizedBox(height: BananSpacing.xs),
              Text(s.yourPoints(balance),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
            const SizedBox(height: BananSpacing.lg),
            if (items.isEmpty)
              Text(s.noRewards, style: theme.textTheme.bodyMedium),
            for (final it in items)
              Builder(builder: (_) {
                final m = (it as Map).cast<String, dynamic>();
                final pts = ((m['points'] as num?) ?? 0).toInt();
                final enough = balance != null && balance >= pts;
                return Card(
                  child: ListTile(
                    title: Text(m['name'] as String? ?? ''),
                    subtitle: Text(s.rewardPoints(pts)),
                    trailing: FilledButton(
                      onPressed: (session == null || !enough)
                          ? null
                          : () => context.push('/contact'),
                      child: Text(session == null
                          ? s.signIn
                          : (enough ? s.redeemWord : s.notEnough)),
                    ),
                  ),
                );
              }),
            const SizedBox(height: BananSpacing.md),
            Text(
              s.rewardsNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        );
      },
    );
  }
}

// ── shared bits ──────────────────────────────────────────────────────────────
class _CopyTile extends ConsumerWidget {
  const _CopyTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    return Card(
      child: ListTile(
        title: Text(label, style: theme.textTheme.bodySmall),
        subtitle: Text(value, style: theme.textTheme.titleSmall),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: s.copyLabel,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(s.copied)),
            );
          },
        ),
      ),
    );
  }
}

class _LoginPrompt extends ConsumerWidget {
  const _LoginPrompt({required this.message});
  final String message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          const SizedBox(height: BananSpacing.md),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: Text(ref.watch(stringsProvider).signIn),
          ),
        ],
      ),
    );
  }
}
