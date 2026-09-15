import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// "Tra cứu chi tiêu": anyone can type a phone number and see what the
/// counter POS recorded for it — total spend, the Micho it is worth and
/// whether the 5% member discount applies. Logged-in customers get their
/// own phone pre-filled.
class SpendLookupScreen extends ConsumerStatefulWidget {
  const SpendLookupScreen({super.key});

  @override
  ConsumerState<SpendLookupScreen> createState() => _SpendLookupScreenState();
}

class _SpendLookupScreenState extends ConsumerState<SpendLookupScreen> {
  final _phone = TextEditingController();
  bool _loading = false;
  Result<SpendLookup, AppFailure>? _result;

  @override
  void initState() {
    super.initState();
    final own = ref.read(authSessionProvider).valueOrNull?.user.phone;
    if (own != null && own.isNotEmpty) {
      _phone.text = own;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final phone = _phone.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 9) return;
    setState(() {
      _loading = true;
      _result = null;
    });
    final res = await ref.read(spendLookupApiProvider).lookup(phone);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.spendLookup)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(s.spendLookupIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: BananSpacing.lg),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: InputDecoration(
                  labelText: s.spendLookupPhone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                onSubmitted: (_) => _lookup(),
              ),
              const SizedBox(height: BananSpacing.md),
              FilledButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(s.spendLookupSubmit),
              ),
              const SizedBox(height: BananSpacing.xl),
              if (_result != null)
                _result!.when(
                  failure: (f) => Text(
                    f.message ?? f.code,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  success: (r) => _ResultCard(result: r),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.result});
  final SpendLookup result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final isGuest = ref.watch(authSessionProvider).valueOrNull == null;

    if (!result.found) {
      return Container(
        padding: const EdgeInsets.all(BananSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          border: Border.all(color: theme.dividerColor),
        ),
        child: Text(s.spendLookupNotFound),
      );
    }

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                value,
                style: (strong
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: BananColors.primary.withValues(alpha: 0.06),
        border: Border.all(color: BananColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.name != null)
            Text(result.name!, style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.sm),
          row(s.spendLookupTotal, fmt.format(result.totalSpendVnd),
              strong: true),
          row(s.spendLookupVisits, '${result.invoiceCount}'),
          if (result.lastVisitAt != null)
            row(
              s.spendLookupLastVisit,
              DateFormat('dd/MM/yyyy').format(result.lastVisitAt!.toLocal()),
            ),
          row(s.spendLookupMicho, '${result.micho} Micho'),
          const Divider(height: BananSpacing.xl),
          Row(
            children: [
              Icon(
                result.discountEligible
                    ? Icons.verified_rounded
                    : Icons.hourglass_bottom_rounded,
                color: result.discountEligible
                    ? BananColors.success
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  result.discountEligible
                      ? s.spendLookupDiscountOn(
                          (result.discountRate * 100).round(),
                        )
                      : s.spendLookupDiscountOff(
                          fmt.format(result.discountThresholdVnd),
                          (result.discountRate * 100).round(),
                        ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (isGuest) ...[
            const SizedBox(height: BananSpacing.lg),
            Text(
              result.hasAccount
                  ? s.spendLookupHasAccount
                  : s.spendLookupCreateAccount,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: BananSpacing.sm),
            FilledButton.tonal(
              onPressed: () =>
                  context.go(result.hasAccount ? '/login' : '/register'),
              child: Text(result.hasAccount ? s.signIn : s.createAccount),
            ),
          ],
        ],
      ),
    );
  }
}
