import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Floating "Liên hệ" button rendered above the page content on the
/// customer site. Tap → bottom sheet with a row per configured channel
/// (Zalo / Phone / Messenger / Email). Channels come from
/// `DisplayConfig` so the merchant configures them in admin once and
/// every customer client picks them up via the public config endpoint.
///
/// Hidden entirely when no channel is configured — never an empty FAB.
class ContactFab extends ConsumerWidget {
  const ContactFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(displayConfigProvider).valueOrNull;
    if (cfg == null || !cfg.hasAnyContactChannel) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: BananSpacing.lg,
      // Sit above the "Xem giỏ" FAB when both are present (cart FAB is
      // at ~16dp + 56dp; offset us higher).
      bottom: BananSpacing.lg + 80,
      child: FloatingActionButton(
        heroTag: 'contact_fab',
        backgroundColor: BananColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Liên hệ',
        onPressed: () => _openSheet(context, cfg),
        child: const Icon(Icons.support_agent_outlined),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, DisplayConfig cfg) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BananSpacing.lg,
            0,
            BananSpacing.lg,
            BananSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cần hỗ trợ?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: BananSpacing.xs),
              Text(
                'Chọn kênh phù hợp. Đội Banan trả lời nhanh nhất qua '
                'Zalo trong giờ mở cửa.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: BananSpacing.md),
              if (cfg.contactZaloOaId != null &&
                  cfg.contactZaloOaId!.isNotEmpty)
                _ChannelTile(
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF0068FF), // Zalo blue
                  title: 'Zalo Official Account',
                  subtitle: 'Mở Zalo và chat với đội Banan',
                  onTap: () => _launch('https://zalo.me/${cfg.contactZaloOaId}'),
                ),
              if (cfg.contactMessengerId != null &&
                  cfg.contactMessengerId!.isNotEmpty)
                _ChannelTile(
                  icon: Icons.facebook,
                  iconColor: const Color(0xFF0084FF),
                  title: 'Facebook Messenger',
                  subtitle: 'Nhắn tin qua trang Banan',
                  onTap: () => _launch('https://m.me/${cfg.contactMessengerId}'),
                ),
              if (cfg.contactPhone != null && cfg.contactPhone!.isNotEmpty)
                _ChannelTile(
                  icon: Icons.phone_outlined,
                  iconColor: BananColors.success,
                  title: cfg.contactPhone!,
                  subtitle: 'Gọi trực tiếp',
                  onTap: () => _launch('tel:${cfg.contactPhone}'),
                ),
              if (cfg.contactEmail != null && cfg.contactEmail!.isNotEmpty)
                _ChannelTile(
                  icon: Icons.email_outlined,
                  iconColor: BananColors.gold,
                  title: cfg.contactEmail!,
                  subtitle: 'Gửi email',
                  onTap: () => _launch('mailto:${cfg.contactEmail}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BananRadii.rmd,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.sm,
          vertical: BananSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
