import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public landing page of internal.banancakes.vn: the 4 function cards.
/// No login required to LOOK — each card routes into its area and the
/// router's group guards take over (login + returnTo where needed).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Banan · Nội bộ',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: BananColors.primary, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (session == null)
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.md),
              child: TextButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Đăng nhập'),
                onPressed: () => context.go('/login'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.md),
              child: PopupMenuButton<String>(
                tooltip: 'Tài khoản',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (v) async {
                  if (v == 'logout') {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(session.user.email, overflow: TextOverflow.ellipsis),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(value: 'logout', child: Text('Đăng xuất')),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: BananSpacing.lg),
                  Text('Công cụ vận hành Banan', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: BananSpacing.sm),
                  Text(
                    'Chọn chức năng bên dưới. Một số mục cần đăng nhập.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: BananSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final columns = w >= 1100 ? 4 : (w >= 640 ? 2 : 1);
                      const spacing = BananSpacing.lg;
                      final cardWidth = (w - spacing * (columns - 1)) / columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final card in _cards)
                            SizedBox(width: cardWidth, child: _FunctionCard(spec: card)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: BananSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeCardSpec {
  const HomeCardSpec({
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    this.path,
    this.primaryAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;

  /// Whole-card tap target (single-action cards).
  final String? path;
  final ({String label, String path})? primaryAction;
  final ({String label, String path})? secondaryAction;
}

const _cards = <HomeCardSpec>[
  HomeCardSpec(
    icon: Icons.fact_check_outlined,
    title: 'QC chi nhánh',
    badge: 'Admin',
    description: 'Checklist kiểm tra chất lượng tại chi nhánh, chấm điểm và báo cáo PDF.',
    path: '/qc',
  ),
  HomeCardSpec(
    icon: Icons.visibility_outlined,
    title: 'Mystery Shopper',
    badge: 'Nhân viên có thể tạo link',
    description: 'Tạo link đánh giá trải nghiệm khách hàng bí mật cho từng chi nhánh.',
    primaryAction: (label: 'Tạo link Mystery Shopper', path: '/ms/create'),
    secondaryAction: (label: 'Quản lý & xem báo cáo', path: '/ms'),
  ),
  HomeCardSpec(
    icon: Icons.school_outlined,
    title: 'Đào tạo',
    badge: 'Trainee / Admin',
    description: 'Tài liệu, video hướng dẫn và lộ trình đào tạo cho nhân viên.',
    path: '/training',
  ),
  HomeCardSpec(
    icon: Icons.calendar_month_outlined,
    title: 'Lịch làm việc',
    badge: 'Admin',
    description: 'Xếp lịch tuần cho 4 chi nhánh và xuất ảnh gửi nhóm.',
    path: '/schedule',
  ),
];

class _FunctionCard extends StatelessWidget {
  const _FunctionCard({required this.spec});
  final HomeCardSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BananColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, color: BananColors.primary, size: 22),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    _RoleBadge(label: spec.badge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          Text(spec.description, style: theme.textTheme.bodySmall),
          if (spec.primaryAction != null) ...[
            const SizedBox(height: BananSpacing.md),
            FilledButton(
              onPressed: () => context.go(spec.primaryAction!.path),
              child: Text(spec.primaryAction!.label, textAlign: TextAlign.center),
            ),
          ],
          if (spec.secondaryAction != null) ...[
            const SizedBox(height: BananSpacing.xs),
            TextButton(
              onPressed: () => context.go(spec.secondaryAction!.path),
              child: Text(spec.secondaryAction!.label),
            ),
          ],
          if (spec.path != null) ...[
            const SizedBox(height: BananSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_forward, size: 18, color: theme.hintColor),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: spec.path != null
          ? InkWell(onTap: () => context.go(spec.path!), child: body)
          : body,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BananSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
