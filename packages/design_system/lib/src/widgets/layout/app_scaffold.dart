import 'package:flutter/material.dart';

import '../../responsive/breakpoint_builder.dart';

/// Banan app shell. On mobile/tablet narrow widths, the [body] fills the
/// scaffold. On larger surfaces (md+), the body is centered with a max width
/// so dashboards and content pages don't sprawl on ultra-wide monitors.
///
/// The page background (washi colour + faint seigaiha wave) is painted once
/// at the app root via [BananPageBackground] so EVERY screen — whether it
/// uses [AppScaffold] or a bare [Scaffold] — gets the exact same texture.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.maxContentWidth = 1320,
    this.padded = true,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final double maxContentWidth;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: BreakpointBuilder(
          builder: (context, bp) {
            final content = padded
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: bp.isMobile ? 16 : 24,
                      vertical: 16,
                    ),
                    child: body,
                  )
                : body;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
