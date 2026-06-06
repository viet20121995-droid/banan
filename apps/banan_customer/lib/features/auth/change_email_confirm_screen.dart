import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public "confirm email change" screen reached from the link emailed to the
/// NEW address. The [token] arrives as a query parameter. On load we call
/// `confirmEmailChange(token)`; on success the change is complete and the
/// customer is asked to sign in again with the new email, otherwise we show
/// an invalid/expired-link message. Guest-allowed (no session required).
class ChangeEmailConfirmScreen extends ConsumerStatefulWidget {
  const ChangeEmailConfirmScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ChangeEmailConfirmScreen> createState() =>
      _ChangeEmailConfirmScreenState();
}

class _ChangeEmailConfirmScreenState
    extends ConsumerState<ChangeEmailConfirmScreen> {
  bool _loading = true;
  String? _newEmail;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  Future<void> _confirm() async {
    if (widget.token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Liên kết không hợp lệ hoặc đã hết hạn.';
      });
      return;
    }
    final res =
        await ref.read(authRepositoryProvider).confirmEmailChange(widget.token);
    if (!mounted) return;
    res.when(
      success: (email) => setState(() {
        _loading = false;
        _newEmail = email;
      }),
      failure: (f) => setState(() {
        _loading = false;
        _error = f is ValidationFailure
            ? 'Liên kết không hợp lệ hoặc đã hết hạn.'
            : authFailureMessage(f);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: _buildBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: BananSpacing.lg),
          Text('Đang xác nhận đổi email…', textAlign: TextAlign.center),
        ],
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.link_off_outlined,
              size: 56, color: theme.colorScheme.error),
          const SizedBox(height: BananSpacing.lg),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: BananSpacing.xl),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Đăng nhập'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: BananColors.success,
        ),
        const SizedBox(height: BananSpacing.lg),
        Text(
          'Đã đổi email thành công. Vui lòng đăng nhập lại.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        if (_newEmail != null && _newEmail!.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(
            _newEmail!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: BananSpacing.xl),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Đăng nhập'),
        ),
      ],
    );
  }
}
