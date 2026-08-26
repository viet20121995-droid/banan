import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/widgets.dart';
import '../qc/qc_list_screen.dart' show storesProvider;

class MsListScreen extends ConsumerStatefulWidget {
  const MsListScreen({super.key});

  @override
  ConsumerState<MsListScreen> createState() => _MsListScreenState();
}

class _MsListScreenState extends ConsumerState<MsListScreen> {
  Result<List<MsListItem>, AppFailure>? _state;
  String? _storeId;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final res = await ref.read(internalApiProvider).msList(storeId: _storeId, status: _status);
    if (mounted) setState(() => _state = res);
  }

  Future<void> _create() async {
    final stores = ref.read(storesProvider).valueOrNull ?? [];
    if (stores.isEmpty) {
      showSnack(context, 'Chưa tải được danh sách chi nhánh.');
      return;
    }
    var storeId = stores.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo nhiệm vụ Mystery Shopper'),
          content: DropdownButtonFormField<String>(
            initialValue: storeId,
            decoration: const InputDecoration(labelText: 'Chi nhánh'),
            items: [
              for (final s in stores) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setLocal(() => storeId = v ?? storeId),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Tạo nháp')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final res = await ref.read(internalApiProvider).msCreate({'storeId': storeId});
    if (!mounted) return;
    res.when(
      success: (d) => context.go('/ms/${d.id}'),
      failure: (f) => showFailure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider).valueOrNull ?? const <StoreRef>[];
    return InternalShell(
      title: 'Mystery Shopper',
      actions: [
        IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: _load),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Wrap(
              spacing: BananSpacing.md,
              runSpacing: BananSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _storeId,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Chi nhánh', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('Tất cả')),
                      for (final s in stores)
                        DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      setState(() => _storeId = v);
                      _load();
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _status,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Trạng thái', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('Tất cả')),
                      for (final s in const [
                        'DRAFT',
                        'ASSIGNED',
                        'OPENED',
                        'SUBMITTED',
                        'NEEDS_REVISION',
                        'APPROVED',
                        'REVOKED',
                        'EXPIRED',
                      ])
                        DropdownMenuItem<String?>(value: s, child: Text(msStatusLabel(s))),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v);
                      _load();
                    },
                  ),
                ),
                PrimaryButton(label: 'Tạo nhiệm vụ', icon: Icons.add, onPressed: _create),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FetchBody<List<MsListItem>>(
              state: _state,
              onRetry: _load,
              builder: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.visibility_outlined,
                    title: 'Chưa có nhiệm vụ nào',
                    message: 'Tạo nhiệm vụ, gửi link bí mật cho người kiểm tra, rồi duyệt kết quả tại đây.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BananSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return ListTile(
                        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        tileColor: Theme.of(context).colorScheme.surface,
                        onTap: () => context.go('/ms/${it.id}'),
                        title: Text('${it.code} · ${it.store.name}'),
                        subtitle: Text(
                          [
                            if (it.createdAt != null) 'Tạo ${vnDate.format(it.createdAt!.toLocal())}',
                            if (it.deadline != null) 'Hạn nộp ${vnDate.format(it.deadline!.toLocal())}',
                          ].join(' · '),
                        ),
                        trailing: Wrap(
                          spacing: BananSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (it.criticalFail)
                              const StatusBadge(label: 'CRITICAL', intent: StatusIntent.danger, dense: true),
                            if (it.totalScore != null)
                              Text('${it.totalScore!.toStringAsFixed(0)}/100',
                                  style: Theme.of(context).textTheme.titleMedium,),
                            StatusBadge(
                              label: msStatusLabel(it.status),
                              intent: msStatusIntent(it.status),
                              dense: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
