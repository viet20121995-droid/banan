import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
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
        _error = f.message ?? ref.read(stringsProvider).sendFailed;
      }),
    );
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final cfg = ref.watch(displayConfigProvider).valueOrNull;
    final hotline = cfg?.contactPhone;
    final email = cfg?.contactEmail;

    return Scaffold(
      appBar: AppBar(title: Text(s.contactTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(s.contactHeading, style: theme.textTheme.headlineMedium),
              const SizedBox(height: BananSpacing.xs),
              Text(
                s.contactIntro,
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
                _form(theme, s),
              const SizedBox(height: BananSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme, AppStrings s) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.sendMessageTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: s.nameReq),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? s.enterName : null,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _email,
            decoration: InputDecoration(labelText: s.emailReq),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || !v.contains('@') || v.length < 5)
                ? s.invalidEmail
                : null,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _phone,
            decoration: InputDecoration(labelText: s.phone),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _subject,
            decoration: InputDecoration(labelText: s.subjectLabel),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            controller: _message,
            decoration: InputDecoration(
              labelText: s.messageReq,
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            validator: (v) =>
                (v == null || v.trim().length < 5) ? s.enterMessage : null,
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
            label: Text(_busy ? s.sending : s.sendMessageBtn),
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

class _SentCard extends ConsumerWidget {
  const _SentCard({required this.onAnother});
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
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
            Text(s.sentTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              s.sentThanks,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: BananSpacing.md),
            TextButton(
              onPressed: onAnother,
              child: Text(s.sendAnother),
            ),
          ],
        ),
      ),
    );
  }
}
