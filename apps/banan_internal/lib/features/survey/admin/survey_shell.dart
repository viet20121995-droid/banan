import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/internal_shell.dart';

/// The survey area's sub-menu, in working order: reports first, then acting
/// on feedback, then configuration. Rendered on EVERY survey admin page so
/// the section never looks like a read-only report again.
const surveySectionTabs = <(String path, String label, IconData icon)>[
  ('/survey/reports', 'Báo cáo', Icons.insights_outlined),
  ('/survey/cases', 'Phản hồi cần xử lý', Icons.support_agent_outlined),
  ('/survey/editor', 'Điều chỉnh khảo sát', Icons.edit_note_outlined),
  ('/survey/link', 'Link & QR', Icons.qr_code_2_outlined),
  ('/survey/rewards', 'Quà tặng', Icons.card_giftcard_outlined),
];

/// InternalShell + the survey sub-menu. Drop-in replacement for
/// InternalShell on the five survey admin screens.
class SurveyShell extends StatelessWidget {
  const SurveyShell({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return InternalShell(
      title: title,
      subtitle: subtitle,
      actions: actions,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horizontally scrollable so all five tabs survive a 390px phone.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.lg,
              vertical: BananSpacing.sm,
            ),
            child: Row(
              children: [
                for (final (path, label, icon) in surveySectionTabs)
                  Padding(
                    padding: const EdgeInsets.only(right: BananSpacing.sm),
                    child: ChoiceChip(
                      avatar: Icon(
                        icon,
                        size: 18,
                        color: location == path ? BananColors.primary : null,
                      ),
                      label: Text(label),
                      selected: location == path,
                      onSelected: (_) {
                        if (location != path) context.go(path);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
