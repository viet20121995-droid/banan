import 'package:flutter/widgets.dart';

import 'breakpoint.dart';

/// Rebuilds [builder] whenever the resolved [Breakpoint] for the available
/// width changes. Cheaper than `LayoutBuilder + MediaQuery` because it only
/// rebuilds on bucket changes, not on every pixel of resize.
class BreakpointBuilder extends StatelessWidget {
  const BreakpointBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, Breakpoint bp) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bp = Breakpoint.fromWidth(constraints.maxWidth);
        return builder(context, bp);
      },
    );
  }
}

extension BreakpointContextX on BuildContext {
  Breakpoint get bp => Breakpoint.fromWidth(MediaQuery.sizeOf(this).width);
}
