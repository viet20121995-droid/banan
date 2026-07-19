import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

const _typeLabels = {'PREVENTIVE': 'Định kỳ', 'CORRECTIVE': 'Sửa chữa'};

/// Maintenance jobs on work centres. Managers plan and complete them; a completed
/// job's downtime feeds the OEE availability figure.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maint = ref.watch(maintenanceProvider(null));
    final canEdit = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bảo trì thiết bị')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openAdd(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Lên lịch'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(maintenanceProvider(null).future),
        child: maint.when(
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
              itemBuilder: (_, i) => _MaintTile(m: list[i], canEdit: canEdit),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AddMaintenanceDialog(),
    );
  }
}

class _MaintTile extends ConsumerWidget {
  const _MaintTile({required this.m, required this.canEdit});
  final MfgMaintenance m;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = m.isDone ? BananColors.success : BananColors.gold;
    final date = m.scheduledDate == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(m.scheduledDate!.toLocal());
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.workCenterName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${_typeLabels[m.type] ?? m.type} · $date'
                  '${m.isDone ? ' · dừng ${m.downtimeMin} phút' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                if (m.note != null && m.note!.isNotEmpty)
                  Text(m.note!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BananRadii.rPill,
            ),
            child: Text(
              m.isDone ? 'Xong' : 'Đã lên lịch',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (canEdit && !m.isDone) ...[
            const SizedBox(width: BananSpacing.sm),
            OutlinedButton(
              onPressed: () => _complete(context, ref),
              child: const Text('Hoàn tất'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '0');
    final minutes = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Hoàn tất bảo trì'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration:
              const InputDecoration(labelText: 'Thời gian dừng máy (phút)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dctx, int.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
    if (minutes == null) return;
    final res = await ref
        .read(manufacturingApiProvider)
        .completeMaintenance(m.id, downtimeMin: minutes);
    if (!context.mounted) return;
    res.when(
      success: (_) => ref.invalidate(maintenanceProvider(null)),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }
}

class _AddMaintenanceDialog extends ConsumerStatefulWidget {
  const _AddMaintenanceDialog();

  @override
  ConsumerState<_AddMaintenanceDialog> createState() =>
      _AddMaintenanceDialogState();
}

class _AddMaintenanceDialogState extends ConsumerState<_AddMaintenanceDialog> {
  String? _workCenterId;
  String _type = 'PREVENTIVE';
  DateTime _date = DateTime.now();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_workCenterId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tổ/máy.')));
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).createMaintenance(
          workCenterId: _workCenterId!,
          scheduledDate: _date,
          type: _type,
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(maintenanceProvider(null));
        Navigator.pop(context);
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workCenters = ref.watch(workCentersProvider);
    return AlertDialog(
      title: const Text('Lên lịch bảo trì'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            workCenters.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _workCenterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tổ / máy'),
                items: [
                  for (final w in list)
                    DropdownMenuItem(value: w.id, child: Text(w.nameVi)),
                ],
                onChanged: (v) => setState(() => _workCenterId = v),
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại'),
              items: [
                for (final e in _typeLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'PREVENTIVE'),
            ),
            const SizedBox(height: BananSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ngày'),
              trailing: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _note,
              decoration:
                  const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
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
            title: 'Chưa có lịch bảo trì',
            message: 'Lên lịch bảo trì để theo dõi thời gian dừng máy.',
            icon: Icons.build_outlined,
          ),
        ],
      );
}
