import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Browser tab title with the unread count in front — "(3) Bếp Banan" —
/// so staff on another tab still see something is waiting. No-op on
/// platforms without a window title.
void setTabTitle(String base, int unread, {Color? primaryColor}) {
  SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(
      label: unread > 0 ? '($unread) $base' : base,
      primaryColor: (primaryColor ?? Colors.white).toARGB32(),
    ),
  );
}
