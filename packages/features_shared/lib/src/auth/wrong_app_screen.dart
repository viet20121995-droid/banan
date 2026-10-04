import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_strings.dart';
import 'auth_controller.dart';

/// Shown when an authenticated user opens the wrong app for their role
/// (e.g. a customer logs into the merchant dashboard).
class WrongAppScreen extends ConsumerWidget {
  const WrongAppScreen({
    required this.expected,
    required this.actual,
    super.key,
  });

  /// Plain-text label of what the app is for ("Store staff", "Kitchen staff").
  final String expected;
  final String actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_person_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: BananSpacing.lg),
              Text(
                s.wrongAppTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.sm),
              Text(
                s.wrongAppBody(expected, actual),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.xl),
              PrimaryButton(
                label: s.signOut,
                expand: true,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
