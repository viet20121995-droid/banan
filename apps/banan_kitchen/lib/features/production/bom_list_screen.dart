import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';

/// Recipes (BoMs). Managers can add a new recipe or open one to edit (editing
/// saves a new version). Everyone else views.
class BomListScreen extends ConsumerWidget {
  const BomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boms = ref.watch(bomListProvider);
    final canEdit = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Công thức (BoM)')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/production/boms/new'),
              icon: const Icon(Icons.add),
              label: const Text('Công thức mới'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bomListProvider.future),
        child: boms.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Text('Lỗi: $e'),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _Empty();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(BananSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.sm),
              itemBuilder: (context, i) {
                final b = list[i];
                final theme = Theme.of(context);
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rmd,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                  ),
                  child: ListTile(
                    title: Text('${b.productNameVi} (${b.productCode})'),
                    subtitle: Text(
                      '${b.outputQty.toStringAsFixed(0)}${b.uomCode} · '
                      '${b.lineCount} nguyên liệu · ${b.opCount} công đoạn',
                    ),
                    trailing: canEdit ? const Icon(Icons.edit_outlined) : null,
                    onTap: canEdit
                        ? () => context.push('/production/boms/${b.id}/edit')
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            title: 'Chưa có công thức',
            message: 'Thêm công thức để tạo lệnh sản xuất từ đó.',
            icon: Icons.menu_book_outlined,
          ),
        ],
      );
}
