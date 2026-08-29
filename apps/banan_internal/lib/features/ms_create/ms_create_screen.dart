import 'dart:math';

import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/widgets.dart';

/// Public employee Mystery Shopper link generator. No account — a shared
/// internal access code (typed here, sent in the POST body, never stored)
/// authorises creation. The raw link appears exactly once, on the success
/// view; the creator can never see submissions, photos, scores or PDFs.
class MsCreateScreen extends ConsumerStatefulWidget {
  const MsCreateScreen({super.key});

  @override
  ConsumerState<MsCreateScreen> createState() => _MsCreateScreenState();
}

/// Per-submission idempotency key — a double-click reuses the same key, so
/// the backend mints exactly one mission.
String newIdempotencyKey() {
  final rng = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}

class _MsCreateScreenState extends ConsumerState<MsCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _employeeCode = TextEditingController();
  final _accessCode = TextEditingController();
  final _note = TextEditingController();
  int _ttlDays = 7;
  String? _storeId;
  String _idempotencyKey = newIdempotencyKey();

  Result<List<StoreRef>, AppFailure>? _stores;
  MsCreateResult? _result;
  bool _busy = false;
  bool _obscureCode = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _name.dispose();
    _employeeCode.dispose();
    _accessCode.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _stores = null);
    final res = await ref.read(internalPublicApiProvider).stores();
    if (mounted) setState(() => _stores = res);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_storeId == null) {
      showSnack(context, 'Chọn chi nhánh cần đánh giá.');
      return;
    }
    setState(() => _busy = true);
    final res = await ref.read(internalPublicApiProvider).createAssignment(
          requesterName: _name.text.trim(),
          employeeCode: _employeeCode.text.trim(),
          accessCode: _accessCode.text,
          storeId: _storeId!,
          ttlDays: _ttlDays,
          note: _note.text.trim(),
          idempotencyKey: _idempotencyKey,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (r) => setState(() => _result = r),
      failure: (f) => showSnack(context, _errorMessage(f)),
    );
  }

  String _errorMessage(AppFailure f) => switch (f.code) {
        'INTERNAL_MS_CODE_INVALID' => 'Mã truy cập nội bộ không đúng — hỏi quản lý của bạn.',
        'INTERNAL_MS_CREATOR_DISABLED' =>
          'Chức năng tạo link chưa được kích hoạt — liên hệ quản trị viên.',
        'INTERNAL_MS_DUPLICATE_REQUEST' =>
          'Yêu cầu này đã được xử lý — bấm "Tạo nhiệm vụ khác" nếu cần link mới.',
        'INTERNAL_MS_STORE_NOT_FOUND' => 'Chi nhánh không hợp lệ — tải lại trang và thử lại.',
        'INTERNAL_MS_NO_TEMPLATE' => 'Hệ thống chưa sẵn sàng — liên hệ quản trị viên.',
        'HTTP_429' => 'Thao tác quá nhanh — chờ một phút rồi thử lại.',
        'NETWORK' || 'TIMEOUT' => 'Không kết nối được — kiểm tra mạng rồi thử lại.',
        _ => f.message ?? 'Không tạo được link — thử lại sau.',
      };

  void _reset() {
    setState(() {
      _result = null;
      _idempotencyKey = newIdempotencyKey();
      _note.clear();
      // Keep name/employee/access code — the same employee usually creates
      // several missions in a row.
      _storeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Trang chủ',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Tạo link Mystery Shopper'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _result != null
                  ? MsCreateSuccessView(result: _result!, onCreateAnother: _reset)
                  : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final storesState = _stores;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Điền thông tin bên dưới để nhận link đánh giá bí mật cho một chi nhánh. '
            'Cần mã truy cập nội bộ (hỏi quản lý nếu chưa có).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: BananSpacing.lg),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ tên người tạo link *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập' : null,
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _employeeCode,
            decoration: const InputDecoration(labelText: 'Mã nhân viên (nếu có)'),
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _accessCode,
            obscureText: _obscureCode,
            decoration: InputDecoration(
              labelText: 'Mã truy cập nội bộ *',
              suffixIcon: IconButton(
                icon: Icon(_obscureCode ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCode = !_obscureCode),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập' : null,
          ),
          const SizedBox(height: BananSpacing.md),
          if (storesState == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BananSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            storesState.when(
              success: (stores) => DropdownButtonFormField<String>(
                initialValue: _storeId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Chi nhánh Mystery Shopper sẽ đánh giá *'),
                items: [
                  for (final s in stores)
                    DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _storeId = v),
              ),
              failure: (_) => Row(
                children: [
                  const Expanded(child: Text('Không tải được danh sách chi nhánh.')),
                  TextButton(onPressed: _loadStores, child: const Text('Thử lại')),
                ],
              ),
            ),
          const SizedBox(height: BananSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _ttlDays,
            decoration: const InputDecoration(labelText: 'Hạn sử dụng link'),
            items: [
              for (var d = 1; d <= 7; d++)
                DropdownMenuItem(value: d, child: Text(d == 7 ? '7 ngày (mặc định)' : '$d ngày')),
            ],
            onChanged: (v) => setState(() => _ttlDays = v ?? 7),
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _note,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tuỳ chọn)',
              helperText: 'VD: đánh giá ca chiều cuối tuần',
            ),
          ),
          const SizedBox(height: BananSpacing.lg),
          PrimaryButton(
            label: 'Tạo link',
            icon: Icons.link,
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Success view — standalone widget so layout tests can pump it directly.
class MsCreateSuccessView extends StatelessWidget {
  const MsCreateSuccessView({required this.result, required this.onCreateAnother, super.key});

  final MsCreateResult result;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 56, color: BananColors.success),
        const SizedBox(height: BananSpacing.md),
        Text(
          'Đã tạo link cho ${result.storeName}',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BananSpacing.xs),
        Text(
          'Mã nhiệm vụ ${result.code} · dùng được đến '
          '${vnDate.format(result.expiresAt.toLocal())}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: BananSpacing.lg),
        Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BananRadii.rmd,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              SelectableText(
                result.url,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: BananSpacing.md),
              FilledButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Sao chép link'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: result.url));
                  if (context.mounted) showSnack(context, 'Đã sao chép link.');
                },
              ),
              const SizedBox(height: BananSpacing.lg),
              Container(
                padding: const EdgeInsets.all(BananSpacing.sm),
                color: Colors.white,
                child: QrImageView(data: result.url, size: 180),
              ),
              const SizedBox(height: BananSpacing.xs),
              Text('Hoặc quét QR bằng điện thoại', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: BananSpacing.md),
        Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            color: BananColors.warning.withValues(alpha: 0.10),
            borderRadius: BananRadii.rmd,
            border: Border.all(color: BananColors.warning),
          ),
          child: const Text(
            'Link này dành cho MỘT nhiệm vụ đánh giá. Chỉ gửi riêng cho người thực hiện — '
            'không đăng lên nhóm chung hoặc mạng xã hội. Link sẽ không hiển thị lại sau khi '
            'rời trang này.',
          ),
        ),
        const SizedBox(height: BananSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tạo nhiệm vụ khác'),
          onPressed: onCreateAnother,
        ),
      ],
    );
  }
}
