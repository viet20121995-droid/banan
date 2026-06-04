import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public list of all Banan branches — accessible without login.
final storesListProvider = FutureProvider<List<Store>>((ref) async {
  final repo = ref.watch(storesRepositoryProvider);
  final res = await repo.list();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi nhánh')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(storesListProvider),
        ),
        data: (stores) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(storesListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(BananSpacing.lg),
            itemCount: stores.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: BananSpacing.md),
            itemBuilder: (context, i) => _StoreCard(store: stores[i]),
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final Store store;

  Future<void> _openMap() async {
    final query = Uri.encodeComponent(store.address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final url = Uri.parse('tel:${store.phone}');
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(BananSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(Icons.storefront_outlined,
                    color: theme.colorScheme.primary,),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Text(store.name, style: theme.textTheme.titleMedium),
              ),
              _OpenClosedChip(open: store.isOpenNow),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          InkWell(
            onTap: _openMap,
            borderRadius: BananRadii.rmd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: BananSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: theme.colorScheme.outline,),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: Text(
                      store.address,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: BananSpacing.xs),
          InkWell(
            onTap: _call,
            borderRadius: BananRadii.rmd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: BananSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 18, color: theme.colorScheme.outline,),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: Text(
                      store.phone,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.call, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: BananSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule_outlined,
                    size: 18, color: theme.colorScheme.outline,),
                const SizedBox(width: BananSpacing.sm),
                Expanded(
                  child: Text(
                    store.hoursSummary,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny green "Open" / grey "Closed" pill.
class _OpenClosedChip extends StatelessWidget {
  const _OpenClosedChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final color = open ? BananColors.success : BananColors.cocoaSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        open ? 'Đang mở' : 'Đóng cửa',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
