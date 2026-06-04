// Map literals built inside collection-for/if trip the trailing-comma lint.
// ignore_for_file: require_trailing_commas
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/shell/merchant_shell.dart';

/// Cài đặt → Nội dung trang: merchant/admin chỉnh sửa FAQ + trang "Về Banan"
/// mà khách nhìn thấy. Lưu vào backend (SiteContent); khách đọc realtime
/// sau khi refresh.
class SiteContentEditorScreen extends StatelessWidget {
  const SiteContentEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MerchantShell(
        title: 'Nội dung trang',
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: 'FAQ', icon: Icon(Icons.help_outline)),
                  Tab(text: 'Về Banan', icon: Icon(Icons.info_outline)),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(children: [_FaqEditor(), _AboutEditor()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pair {
  _Pair(String a, String b)
      : c1 = TextEditingController(text: a),
        c2 = TextEditingController(text: b);
  final TextEditingController c1;
  final TextEditingController c2;
  void dispose() {
    c1.dispose();
    c2.dispose();
  }
}

// ── FAQ editor ──────────────────────────────────────────────────────────

class _FaqEditor extends ConsumerStatefulWidget {
  const _FaqEditor();
  @override
  ConsumerState<_FaqEditor> createState() => _FaqEditorState();
}

class _FaqEditorState extends ConsumerState<_FaqEditor> {
  final List<_Pair> _rows = [];
  bool _loading = true;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ref.read(siteContentApiProvider).getForEdit('faq');
    if (!mounted) return;
    res.when(
      success: (c) {
        _rows
          ..clear()
          ..addAll(c.faqItems.map((e) => _Pair(e.q, e.a)));
        if (_rows.isEmpty) _rows.add(_Pair('', ''));
        setState(() => _loading = false);
      },
      failure: (f) => setState(() {
        _loading = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final items = [
      for (final r in _rows)
        if (r.c1.text.trim().isNotEmpty || r.c2.text.trim().isNotEmpty)
          {'q': r.c1.text.trim(), 'a': r.c2.text.trim()},
    ];
    final res = await ref
        .read(siteContentApiProvider)
        .update('faq', {'items': items});
    if (!mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(faqContentProvider);
        setState(() {
          _busy = false;
          _msg = 'Đã lưu ${items.length} câu hỏi.';
        });
      },
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Text(
          'Câu hỏi thường gặp hiển thị cho khách ở trang /faq. Kéo thêm/bớt '
          'câu hỏi rồi bấm Lưu.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: BananSpacing.md),
        for (var i = 0; i < _rows.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(BananSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Câu hỏi ${i + 1}',
                            style: theme.textTheme.titleSmall),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Xoá',
                        onPressed: () => setState(() {
                          _rows.removeAt(i).dispose();
                          if (_rows.isEmpty) _rows.add(_Pair('', ''));
                        }),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _rows[i].c1,
                    decoration: const InputDecoration(labelText: 'Câu hỏi'),
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  TextField(
                    controller: _rows[i].c2,
                    decoration: const InputDecoration(labelText: 'Trả lời'),
                    minLines: 2,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _rows.add(_Pair('', ''))),
          icon: const Icon(Icons.add),
          label: const Text('Thêm câu hỏi'),
        ),
        const SizedBox(height: BananSpacing.md),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(_busy ? 'Đang lưu…' : 'Lưu FAQ'),
        ),
        if (_msg != null) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(_msg!, style: theme.textTheme.titleSmall),
        ],
      ],
    );
  }
}

// ── About editor ──────────────────────────────────────────────────────────

class _AboutEditor extends ConsumerStatefulWidget {
  const _AboutEditor();
  @override
  ConsumerState<_AboutEditor> createState() => _AboutEditorState();
}

class _AboutEditorState extends ConsumerState<_AboutEditor> {
  final _intro = TextEditingController();
  final List<_Pair> _sections = [];
  bool _loading = true;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _intro.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ref.read(siteContentApiProvider).getForEdit('about');
    if (!mounted) return;
    res.when(
      success: (c) {
        _intro.text = c.aboutIntro;
        _sections
          ..clear()
          ..addAll(c.aboutSections.map((s) => _Pair(s.heading, s.body)));
        if (_sections.isEmpty) _sections.add(_Pair('', ''));
        setState(() => _loading = false);
      },
      failure: (f) => setState(() {
        _loading = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final sections = [
      for (final s in _sections)
        if (s.c1.text.trim().isNotEmpty || s.c2.text.trim().isNotEmpty)
          {'heading': s.c1.text.trim(), 'body': s.c2.text.trim()},
    ];
    final res = await ref.read(siteContentApiProvider).update('about', {
      'intro': _intro.text.trim(),
      'sections': sections,
    });
    if (!mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(aboutContentProvider);
        setState(() {
          _busy = false;
          _msg = 'Đã lưu trang Về Banan.';
        });
      },
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Text(
          'Nội dung trang "Về Banan" (/about). Mỗi mục có tiêu đề + nội dung; '
          'xuống dòng 2 lần để tách đoạn.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: BananSpacing.md),
        TextField(
          controller: _intro,
          decoration: const InputDecoration(
            labelText: 'Giới thiệu (intro)',
            alignLabelWithHint: true,
          ),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: BananSpacing.md),
        Text('Các mục', style: theme.textTheme.titleMedium),
        const SizedBox(height: BananSpacing.xs),
        for (var i = 0; i < _sections.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(BananSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Mục ${i + 1}',
                            style: theme.textTheme.titleSmall),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          _sections.removeAt(i).dispose();
                          if (_sections.isEmpty) _sections.add(_Pair('', ''));
                        }),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _sections[i].c1,
                    decoration: const InputDecoration(labelText: 'Tiêu đề mục'),
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  TextField(
                    controller: _sections[i].c2,
                    decoration: const InputDecoration(labelText: 'Nội dung'),
                    minLines: 3,
                    maxLines: 10,
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _sections.add(_Pair('', ''))),
          icon: const Icon(Icons.add),
          label: const Text('Thêm mục'),
        ),
        const SizedBox(height: BananSpacing.md),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(_busy ? 'Đang lưu…' : 'Lưu trang Về Banan'),
        ),
        if (_msg != null) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(_msg!, style: theme.textTheme.titleSmall),
        ],
      ],
    );
  }
}
