import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Trang liên hệ — form gửi tin nhắn hỗ trợ + hotline gọi nhanh.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(contactApiProvider).submit(
          name: _name.text.trim(),
          email: _email.text.trim(),
          message: _message.text.trim(),
          phone: _phone.text.trim(),
          subject: _subject.text.trim(),
        );
    if (!mounted) return;
    res.when(
      success: (_) => setState(() {
        _busy = false;
        _sent = true;
      }),
      failure: (f) => setState(() {
        _busy = false;
        _error = f.message ?? 'Gửi không thành công, vui lòng thử lại.';
      }),
    );
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = ref.watch(displayConfigProvider).valueOrNull;
    final hotline = cfg?.contactPhone;
    final email = cfg?.contactEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Liên hệ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text('Liên hệ với Banan', style: theme.textTheme.headlineMedium),
              const SizedBox(height: BananSpacing.xs),
              Text(
                'Có thắc mắc về đơn hàng, đặt bánh theo yêu cầu hay hợp tác? '
                'Gửi tin nhắn cho chúng tôi, hoặc gọi hotline để được hỗ trợ '
                'ngay.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: BananSpacing.lg),

              // Hotline / email quick actions (from chain display config).
              if (hotline != null && hotline.isNotEmpty)
                _ContactTile(
                  icon: Icons.phone_in_talk_outlined,
                  label: 'Hotline',
                  value: hotline,
                  onTap: () => _call(hotline),
                ),
              if (email != null && email.isNotEmpty)
                _ContactTile(
                  icon: Icons.alternate_email,
                  label: 'Email',
                  value: email,
                  onTap: () => launchUrl(Uri.parse('mailto:$email')),
                ),
              const SizedBox(height: BananSpacing.lg),

              if (_sent)
                _SentCard(onAnother: () => setState(() => _sent = false))
              else
                _form(theme),
              const SizedBox(height: BananSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gửi tin nhắn', style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ tên *'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Nhập họ tên' : null,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email *'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || !v.contains('@') || v.length < 5)
                ? 'Email không hợp lệ'
                : null,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Chủ đề'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _message,
            decoration: const InputDecoration(
              labelText: 'Nội dung *',
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            validator: (v) =>
                (v == null || v.trim().length < 5) ? 'Nhập nội dung' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error),),
          ],
          const SizedBox(height: BananSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_busy ? 'Đang gửi…' : 'Gửi tin nhắn'),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: theme.textTheme.bodySmall),
        subtitle: Text(value, style: theme.textTheme.titleSmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.onAnother});
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: BananColors.success.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.lg),
        child: Column(
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: BananColors.success,
            ),
            const SizedBox(height: BananSpacing.sm),
            Text('Đã gửi tin nhắn!', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cảm ơn bạn đã liên hệ. Chúng tôi sẽ phản hồi sớm nhất qua email.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: BananSpacing.md),
            TextButton(
              onPressed: onAnother,
              child: const Text('Gửi tin nhắn khác'),
            ),
          ],
        ),
      ),
    );
  }
}
