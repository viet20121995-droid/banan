/// Material-aligned responsive breakpoints. See docs/00-architecture.md.
enum Breakpoint {
  xs, // < 600
  sm, // 600–904
  md, // 905–1239
  lg, // 1240–1439
  xl; // ≥ 1440

  static Breakpoint fromWidth(double width) {
    if (width < 600) return Breakpoint.xs;
    if (width < 905) return Breakpoint.sm;
    if (width < 1240) return Breakpoint.md;
    if (width < 1440) return Breakpoint.lg;
    return Breakpoint.xl;
  }

  bool get isMobile => this == Breakpoint.xs;
  bool get isTablet => this == Breakpoint.sm || this == Breakpoint.md;
  bool get isDesktop => this == Breakpoint.lg || this == Breakpoint.xl;
  bool get isAtLeastMd => index >= Breakpoint.md.index;
  bool get isAtLeastLg => index >= Breakpoint.lg.index;
}
