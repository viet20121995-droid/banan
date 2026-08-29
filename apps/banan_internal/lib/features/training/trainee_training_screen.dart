import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/save_file.dart';
import '../../shared/widgets.dart';

/// Training as a TRAINEE sees it: their own path/progress + the published
/// material library. Read + mark-own-progress only — every admin action
/// (create/reissue/assign/scores) lives on the ADMIN screen and is enforced
/// by the backend regardless of what this UI shows.
class TraineeTrainingScreen extends ConsumerStatefulWidget {
  const TraineeTrainingScreen({super.key});

  @override
  ConsumerState<TraineeTrainingScreen> createState() => _TraineeTrainingScreenState();
}

class _TraineeTrainingScreenState extends ConsumerState<TraineeTrainingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  Result<MyTraining, AppFailure>? _me;
  Result<List<MaterialView>, AppFailure>? _materials;

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadMaterials();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    setState(() => _me = null);
    final res = await _api.myTraining();
    if (mounted) setState(() => _me = res);
  }

  Future<void> _loadMaterials() async {
    setState(() => _materials = null);
    final res = await _api.myMaterials();
    if (mounted) setState(() => _materials = res);
  }

  Future<void> _markDone(ProgressView p) async {
    final ok = await confirmDialog(
      context,
      title: 'Báo đã học xong?',
      message: '"${p.material.title}" sẽ chuyển sang "Chờ xác nhận" — '
          'quản trị viên kiểm tra và xác nhận hoàn thành.',
      confirmLabel: 'Báo đã xong',
    );
    if (!ok || !mounted) return;
    final res = await _api.updateOwnProgress(p.id, 'COMPLETED');
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã gửi — chờ quản trị viên xác nhận.');
        _loadMe();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  void _openMaterial(MaterialView m) {
    final url = (m.url ?? '').trim();
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      showSnack(context, 'Đường dẫn không hợp lệ — báo quản trị viên.');
      return;
    }
    openExternalUrl(url);
  }

  Future<void> _downloadMaterial(MaterialView m) async {
    final res = await _api.fileBytes(m.url!);
    if (!mounted) return;
    res.when(
      success: (bytes) {
        saveBytesAsFile(bytes, '${m.title}.pdf', 'application/pdf');
        showSnack(context, 'Đã tải PDF.');
      },
      failure: (f) => showFailure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InternalShell(
      title: 'Đào tạo của tôi',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _loadMe();
            _loadMaterials();
          },
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Lộ trình của tôi'), Tab(text: 'Tài liệu')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_myPathTab(), _materialsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _myPathTab() {
    return FetchBody<MyTraining>(
      state: _me,
      onRetry: _loadMe,
      builder: (me) {
        if (me.person == null) {
          return const EmptyState(
            icon: Icons.badge_outlined,
            title: 'Tài khoản chưa được liên kết hồ sơ',
            message: 'Báo quản trị viên liên kết tài khoản của bạn với hồ sơ nhân sự '
                'để xem lộ trình đào tạo.',
          );
        }
        if (me.assignments.isEmpty) {
          return const EmptyState(
            icon: Icons.route_outlined,
            title: 'Chưa được gán lộ trình',
            message: 'Khi quản trị viên gán lộ trình đào tạo, nội dung sẽ hiện tại đây. '
                'Bạn vẫn xem được tài liệu ở tab bên cạnh.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            for (final a in me.assignments) ...[
              Text(
                '${a.path.name} · bắt đầu ${vnDate.format(a.startDate.toLocal())} · '
                'hoàn thành ${a.percentDone}%',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: BananSpacing.sm),
              for (final p in a.progress)
                ListTile(
                  shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                  tileColor: Theme.of(context).colorScheme.surface,
                  title: Text(p.material.title),
                  subtitle: Text(
                    [
                      progressStatusLabel(p.effectiveStatus),
                      if (p.dueAt != null) 'hạn ${vnDate.format(p.dueAt!.toLocal())}',
                      if (!p.isRequired) 'tuỳ chọn',
                    ].join(' · '),
                  ),
                  leading: StatusBadge(
                    label: progressStatusLabel(p.effectiveStatus),
                    intent: progressStatusIntent(p.effectiveStatus),
                    dense: true,
                  ),
                  trailing: Wrap(
                    spacing: BananSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (p.material.kind != 'FILE' && p.material.url != null)
                        IconButton(
                          tooltip: p.material.kind == 'VIDEO' ? 'Mở video' : 'Mở liên kết',
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: () => _openMaterial(p.material),
                        ),
                      if (p.material.kind == 'FILE' && p.material.url != null)
                        IconButton(
                          tooltip: 'Tải PDF',
                          icon: const Icon(Icons.download_outlined, size: 20),
                          onPressed: () => _downloadMaterial(p.material),
                        ),
                      if (p.status != 'COMPLETED' && p.status != 'PENDING_CONFIRMATION')
                        FilledButton.tonal(
                          onPressed: () => _markDone(p),
                          child: const Text('Báo đã xong'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: BananSpacing.lg),
            ],
          ],
        );
      },
    );
  }

  Widget _materialsTab() {
    return FetchBody<List<MaterialView>>(
      state: _materials,
      onRetry: _loadMaterials,
      builder: (materials) {
        if (materials.isEmpty) {
          return const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Chưa có tài liệu',
            message: 'Tài liệu đào tạo sẽ hiện tại đây khi được phát hành.',
          );
        }
        final byCategory = <String, List<MaterialView>>{};
        for (final m in materials) {
          byCategory.putIfAbsent(m.category, () => []).add(m);
        }
        return ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            for (final entry in byCategory.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
                child: Text(
                  trainingCategoryLabel(entry.key),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: BananColors.primary),
                ),
              ),
              for (final m in entry.value)
                ListTile(
                  shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                  tileColor: Theme.of(context).colorScheme.surface,
                  title: Text('${m.title} (v${m.version})'),
                  subtitle: Text(
                    [
                      switch (m.kind) {
                        'FILE' => 'PDF',
                        'VIDEO' => 'Video',
                        _ => 'Link',
                      },
                      if (m.estimatedMinutes != null) '${m.estimatedMinutes} phút',
                      if (m.description != null) m.description!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Wrap(
                    spacing: BananSpacing.xs,
                    children: [
                      if (m.kind != 'FILE' && m.url != null)
                        IconButton(
                          tooltip: m.kind == 'VIDEO' ? 'Mở video' : 'Mở liên kết',
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: () => _openMaterial(m),
                        ),
                      if (m.kind == 'FILE' && m.url != null)
                        IconButton(
                          tooltip: 'Tải PDF',
                          icon: const Icon(Icons.download_outlined, size: 20),
                          onPressed: () => _downloadMaterial(m),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: BananSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}
