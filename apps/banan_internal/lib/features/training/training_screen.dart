import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/save_file.dart';
import '../../shared/widgets.dart';
import '../qc/qc_list_screen.dart' show storesProvider;

/// Training hub: staff roster, material library, learning paths, progress.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  Result<List<PersonView>, AppFailure>? _people;
  Result<List<MaterialView>, AppFailure>? _materials;
  Result<List<PathView>, AppFailure>? _paths;
  Result<List<TrainingOverviewRow>, AppFailure>? _progress;
  bool _overdueOnly = false;
  String? _storeFilter;

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPeople(), _loadMaterials(), _loadPaths(), _loadProgress()]);
  }

  Future<void> _loadPeople() async {
    setState(() => _people = null);
    final res = await _api.people(storeId: _storeFilter);
    if (mounted) setState(() => _people = res);
  }

  Future<void> _loadMaterials() async {
    setState(() => _materials = null);
    final res = await _api.materials();
    if (mounted) setState(() => _materials = res);
  }

  Future<void> _loadPaths() async {
    setState(() => _paths = null);
    final res = await _api.paths();
    if (mounted) setState(() => _paths = res);
  }

  Future<void> _loadProgress() async {
    setState(() => _progress = null);
    final res = await _api.trainingProgress(storeId: _storeFilter, overdueOnly: _overdueOnly);
    if (mounted) setState(() => _progress = res);
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider).valueOrNull ?? const <StoreRef>[];
    return InternalShell(
      title: 'Training — Đào tạo',
      actions: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            initialValue: _storeFilter,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chi nhánh', isDense: true),
            items: [
              const DropdownMenuItem<String?>(child: Text('Tất cả')),
              for (final s in stores)
                DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              setState(() => _storeFilter = v);
              _loadPeople();
              _loadProgress();
            },
          ),
        ),
        IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: _loadAll),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Nhân sự'),
              Tab(text: 'Tài liệu'),
              Tab(text: 'Lộ trình'),
              Tab(text: 'Tiến độ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_peopleTab(), _materialsTab(), _pathsTab(), _progressTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nhân sự ──
  Widget _peopleTab() {
    return FetchBody<List<PersonView>>(
      state: _people,
      onRetry: _loadPeople,
      builder: (people) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Row(
              children: [
                Text('${people.length} nhân sự', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                PrimaryButton(
                  label: 'Thêm nhân sự',
                  icon: Icons.person_add_alt,
                  onPressed: _personDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Chưa có hồ sơ nhân sự',
                    message: 'Thêm nhân viên để gán lộ trình đào tạo và xếp lịch làm.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      BananSpacing.lg,
                      0,
                      BananSpacing.lg,
                      BananSpacing.lg,
                    ),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.xs),
                    itemBuilder: (context, i) {
                      final p = people[i];
                      return ListTile(
                        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        tileColor: Theme.of(context).colorScheme.surface,
                        title: Text(p.fullName),
                        subtitle: Text(
                          '${p.position} · ${p.store?.name ?? '—'}'
                          '${p.startDate != null ? ' · từ ${vnDate.format(p.startDate!.toLocal())}' : ''}',
                        ),
                        trailing: Wrap(
                          spacing: BananSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!p.isActive)
                              const StatusBadge(
                                label: 'Ngưng làm',
                                intent: StatusIntent.danger,
                                dense: true,
                              ),
                            IconButton(
                              tooltip: 'Gán lộ trình',
                              icon: const Icon(Icons.playlist_add, size: 20),
                              onPressed: () => _assignDialog(p),
                            ),
                            IconButton(
                              tooltip: 'Sửa',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _personDialog(person: p),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _personDialog({PersonView? person}) async {
    final stores = ref.read(storesProvider).valueOrNull ?? [];
    if (stores.isEmpty) {
      showSnack(context, 'Chưa tải được danh sách chi nhánh.');
      return;
    }
    final name = TextEditingController(text: person?.fullName ?? '');
    final position = TextEditingController(text: person?.position ?? '');
    final notes = TextEditingController(text: person?.notes ?? '');
    var storeId = person?.store?.id ?? stores.first.id;
    var active = person?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(person == null ? 'Thêm nhân sự' : 'Sửa nhân sự'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ tên *'),
                  ),
                  TextField(
                    controller: position,
                    decoration:
                        const InputDecoration(labelText: 'Vị trí * (VD: Pha chế, Thu ngân)'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: storeId,
                    decoration: const InputDecoration(labelText: 'Chi nhánh'),
                    items: [
                      for (final s in stores) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setLocal(() => storeId = v ?? storeId),
                  ),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  if (person != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang làm việc'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || position.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final body = {
      'fullName': name.text.trim(),
      'position': position.text.trim(),
      'storeId': storeId,
      if (notes.text.trim().isNotEmpty || person != null) 'notes': notes.text.trim(),
      if (person != null) 'isActive': active,
    };
    final res = person == null
        ? await _api.createPerson(body)
        : await _api.updatePerson(person.id, body);
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã lưu.');
        _loadPeople();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _assignDialog(PersonView person) async {
    final paths = _paths?.valueOrNull ?? [];
    if (paths.isEmpty) {
      showSnack(context, 'Chưa có lộ trình — tạo ở tab "Lộ trình" trước.');
      return;
    }
    var pathId = paths.first.id;
    var start = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Gán lộ trình cho ${person.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: pathId,
                decoration: const InputDecoration(labelText: 'Lộ trình'),
                items: [
                  for (final p in paths) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setLocal(() => pathId = v ?? pathId),
              ),
              const SizedBox(height: BananSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text('Bắt đầu: ${vnDate.format(start)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime(2026),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setLocal(() => start = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Gán'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.assignPath({
      'personId': person.id,
      'pathId': pathId,
      'startDate': start.toIso8601String(),
    });
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã gán lộ trình.');
        _loadProgress();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  // ── Tài liệu ──
  Widget _materialsTab() {
    return FetchBody<List<MaterialView>>(
      state: _materials,
      onRetry: _loadMaterials,
      builder: (materials) {
        final byCategory = <String, List<MaterialView>>{};
        for (final m in materials) {
          byCategory.putIfAbsent(m.category, () => []).add(m);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(BananSpacing.lg),
              child: Row(
                children: [
                  Text('${materials.length} tài liệu đang hiệu lực',
                      style: Theme.of(context).textTheme.bodySmall,),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Thêm tài liệu',
                    icon: Icons.note_add_outlined,
                    onPressed: _materialDialog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: materials.isEmpty
                  ? const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Chưa có tài liệu',
                      message: 'Thêm tài liệu PDF, video hoặc đường dẫn cho từng nhóm.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        BananSpacing.lg,
                        0,
                        BananSpacing.lg,
                        BananSpacing.lg,
                      ),
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
                                  if (m.isRequired) 'Bắt buộc',
                                  if (m.description != null) m.description!,
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: BananSpacing.xs,
                                children: [
                                  if (m.kind == 'FILE' && m.url != null)
                                    IconButton(
                                      tooltip: 'Tải PDF',
                                      icon: const Icon(Icons.download_outlined, size: 20),
                                      onPressed: () => _downloadMaterial(m),
                                    ),
                                  if (m.kind != 'FILE' && m.url != null)
                                    IconButton(
                                      tooltip: m.kind == 'VIDEO' ? 'Mở video' : 'Mở liên kết',
                                      icon: const Icon(Icons.open_in_new, size: 20),
                                      onPressed: () => _openMaterial(m),
                                    ),
                                  IconButton(
                                    tooltip: 'Phát hành bản mới (giữ bản cũ để truy vết)',
                                    icon: const Icon(Icons.upgrade, size: 20),
                                    onPressed: () => _materialDialog(reissueOf: m),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: BananSpacing.sm),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  /// VIDEO / LINK materials open their external URL in a new tab.
  void _openMaterial(MaterialView m) {
    final url = m.url!.trim();
    // Case-insensitive scheme check, mirroring openExternalUrl's guard —
    // this copy exists only to give the admin feedback instead of a no-op.
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      showSnack(context, 'Đường dẫn không hợp lệ — cần bắt đầu bằng http(s)://');
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

  Future<void> _materialDialog({MaterialView? reissueOf}) async {
    final title = TextEditingController(text: reissueOf?.title ?? '');
    final description = TextEditingController(text: reissueOf?.description ?? '');
    final url = TextEditingController();
    final minutes = TextEditingController(text: reissueOf?.estimatedMinutes?.toString() ?? '');
    var category = reissueOf?.category ?? 'PHA_CHE';
    var kind = reissueOf?.kind ?? 'LINK';
    var required = reissueOf?.isRequired ?? false;
    UploadedFileRef? uploaded;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(reissueOf == null ? 'Thêm tài liệu' : 'Bản mới: ${reissueOf.title}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  ),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Nhóm'),
                    items: [
                      for (final c in const [
                        'PHA_CHE',
                        'CHE_BIEN',
                        'ATVSTP',
                        'QUY_DINH',
                        'DICH_VU_KHACH_HANG',
                      ])
                        DropdownMenuItem(value: c, child: Text(trainingCategoryLabel(c))),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? category),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Loại'),
                    items: const [
                      DropdownMenuItem(value: 'FILE', child: Text('File PDF (tải lên)')),
                      DropdownMenuItem(value: 'VIDEO', child: Text('Video (đường dẫn)')),
                      DropdownMenuItem(value: 'LINK', child: Text('Link tài liệu')),
                    ],
                    onChanged: (v) => setLocal(() => kind = v ?? kind),
                  ),
                  if (kind == 'FILE')
                    Padding(
                      padding: const EdgeInsets.only(top: BananSpacing.sm),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(uploaded == null ? 'Chọn file PDF' : 'Đã tải: sẵn sàng'),
                        onPressed: () async {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );
                          final f = picked?.files.firstOrNull;
                          if (f?.bytes == null) return;
                          final res = await _api.uploadTrainingPdf(
                            bytes: f!.bytes!,
                            filename: f.name,
                          );
                          res.when(
                            success: (u) => setLocal(() => uploaded = u),
                            failure: (fail) {
                              if (context.mounted) showFailure(context, fail);
                            },
                          );
                        },
                      ),
                    )
                  else
                    TextField(
                      controller: url,
                      decoration: const InputDecoration(labelText: 'Đường dẫn (https://…) *'),
                    ),
                  TextField(
                    controller: minutes,
                    decoration: const InputDecoration(labelText: 'Thời lượng ước tính (phút)'),
                    keyboardType: TextInputType.number,
                  ),
                  StatefulBuilder(
                    builder: (context, setSwitch) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bắt buộc'),
                      value: required,
                      onChanged: (v) => setLocal(() => required = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                if (kind == 'FILE' && uploaded == null) return;
                if (kind != 'FILE' && url.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final body = {
      'title': title.text.trim(),
      if (description.text.trim().isNotEmpty) 'description': description.text.trim(),
      'category': category,
      'kind': kind,
      'url': kind == 'FILE' ? uploaded!.name : url.text.trim(),
      'isRequired': required,
      if (int.tryParse(minutes.text.trim()) != null)
        'estimatedMinutes': int.parse(minutes.text.trim()),
    };
    final res = reissueOf == null
        ? await _api.createMaterial(body)
        : await _api.reissueMaterial(reissueOf.id, body);
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã lưu tài liệu.');
        _loadMaterials();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  // ── Lộ trình ──
  Widget _pathsTab() {
    return FetchBody<List<PathView>>(
      state: _paths,
      onRetry: _loadPaths,
      builder: (paths) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Row(
              children: [
                Text('${paths.length} lộ trình', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                PrimaryButton(
                  label: 'Tạo lộ trình',
                  icon: Icons.playlist_add,
                  onPressed: _pathDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: paths.isEmpty
                ? const EmptyState(
                    icon: Icons.route_outlined,
                    title: 'Chưa có lộ trình',
                    message: 'Ghép các tài liệu thành lộ trình theo vị trí (VD: Pha chế mới).',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      BananSpacing.lg,
                      0,
                      BananSpacing.lg,
                      BananSpacing.lg,
                    ),
                    itemCount: paths.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (context, i) {
                      final p = paths[i];
                      return ExpansionTile(
                        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        collapsedShape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.position ?? 'Mọi vị trí'} · ${p.items.length} bài · '
                          '${p.assignmentCount} người đang học',
                        ),
                        children: [
                          for (final (idx, item) in p.items.indexed)
                            ListTile(
                              dense: true,
                              leading: Text('${idx + 1}'),
                              title: Text(item.material.title),
                              subtitle: Text(
                                [
                                  trainingCategoryLabel(item.material.category),
                                  if (item.dueDays != null) 'hạn ${item.dueDays} ngày',
                                  if (!item.isRequired) 'tuỳ chọn',
                                ].join(' · '),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pathDialog() async {
    final materials = _materials?.valueOrNull ?? [];
    if (materials.isEmpty) {
      showSnack(context, 'Chưa có tài liệu — thêm ở tab "Tài liệu" trước.');
      return;
    }
    final name = TextEditingController();
    final position = TextEditingController();
    final selected = <String>{};
    final dueDays = <String, TextEditingController>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo lộ trình đào tạo'),
          content: SizedBox(
            width: 520,
            height: 480,
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên lộ trình *'),
                ),
                TextField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Vị trí áp dụng (VD: Pha chế)'),
                ),
                const SizedBox(height: BananSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn bài theo thứ tự bấm chọn:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final m in materials)
                        CheckboxListTile(
                          dense: true,
                          value: selected.contains(m.id),
                          title: Text(m.title),
                          subtitle: selected.contains(m.id)
                              ? Row(
                                  children: [
                                    Text('Thứ tự ${selected.toList().indexOf(m.id) + 1} · hạn (ngày): '),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        controller: dueDays.putIfAbsent(
                                          m.id,
                                          TextEditingController.new,
                                        ),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(isDense: true),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          onChanged: (v) => setLocal(() {
                            if (v ?? false) {
                              selected.add(m.id);
                            } else {
                              selected.remove(m.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || selected.isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.createPath({
      'name': name.text.trim(),
      if (position.text.trim().isNotEmpty) 'position': position.text.trim(),
      'items': [
        for (final id in selected)
          {
            'materialId': id,
            if (int.tryParse(dueDays[id]?.text.trim() ?? '') != null)
              'dueDays': int.parse(dueDays[id]!.text.trim()),
          },
      ],
    });
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã tạo lộ trình.');
        _loadPaths();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  // ── Tiến độ ──
  Widget _progressTab() {
    return FetchBody<List<TrainingOverviewRow>>(
      state: _progress,
      onRetry: _loadProgress,
      builder: (rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Chỉ hiện quá hạn'),
                  selected: _overdueOnly,
                  onSelected: (v) {
                    setState(() => _overdueOnly = v);
                    _loadProgress();
                  },
                ),
                const Spacer(),
                Text('${rows.length} lượt gán', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(
                    icon: Icons.timeline_outlined,
                    title: 'Chưa có tiến độ',
                    message: 'Gán lộ trình cho nhân sự ở tab "Nhân sự" để theo dõi tại đây.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      BananSpacing.lg,
                      0,
                      BananSpacing.lg,
                      BananSpacing.lg,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return ExpansionTile(
                        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        collapsedShape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                        title: Text('${r.person?.fullName ?? '?'} — ${r.path.name}'),
                        subtitle: Text(
                          '${r.person?.store?.name ?? ''} · bắt đầu ${vnDate.format(r.startDate.toLocal())}'
                          ' · hoàn thành ${r.percentDone}%'
                          '${r.overdueCount > 0 ? ' · ${r.overdueCount} bài quá hạn' : ''}',
                        ),
                        trailing: SizedBox(
                          width: 64,
                          child: LinearProgressIndicator(value: r.percentDone / 100),
                        ),
                        children: [
                          for (final p in r.progress)
                            ListTile(
                              dense: true,
                              title: Text(p.material.title),
                              subtitle: Text(
                                [
                                  progressStatusLabel(p.effectiveStatus),
                                  if (p.dueAt != null) 'hạn ${vnDate.format(p.dueAt!.toLocal())}',
                                  if (p.quizScore != null)
                                    'quiz ${p.quizScore} (lần ${p.attempts})',
                                  if (p.notes != null) p.notes!,
                                ].join(' · '),
                              ),
                              leading: StatusBadge(
                                label: progressStatusLabel(p.effectiveStatus),
                                intent: progressStatusIntent(p.effectiveStatus),
                                dense: true,
                              ),
                              trailing: Wrap(
                                spacing: BananSpacing.xs,
                                children: [
                                  if (p.status != 'COMPLETED')
                                    IconButton(
                                      tooltip: 'Xác nhận hoàn thành',
                                      icon: const Icon(Icons.check_circle_outline, size: 20),
                                      onPressed: () => _markProgress(p, 'COMPLETED'),
                                    ),
                                  IconButton(
                                    tooltip: 'Ghi điểm quiz / ghi chú',
                                    icon: const Icon(Icons.edit_note, size: 20),
                                    onPressed: () => _progressDialog(p),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _markProgress(ProgressView p, String status) async {
    final res = await _api.updateProgress(p.id, {'status': status});
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã cập nhật.');
        _loadProgress();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _progressDialog(ProgressView p) async {
    final quiz = TextEditingController(text: p.quizScore?.toString() ?? '');
    final notes = TextEditingController(text: p.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.material.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quiz,
              decoration: const InputDecoration(labelText: 'Điểm quiz (ghi tay)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.updateProgress(p.id, {
      if (int.tryParse(quiz.text.trim()) != null) 'quizScore': int.parse(quiz.text.trim()),
      'notes': notes.text.trim(),
    });
    if (!mounted) return;
    res.when(
      success: (_) {
        showSnack(context, 'Đã lưu.');
        _loadProgress();
      },
      failure: (f) => showFailure(context, f),
    );
  }
}
