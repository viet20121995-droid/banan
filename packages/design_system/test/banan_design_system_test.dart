import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoint.fromWidth', () {
    test('partitions widths into the documented buckets', () {
      expect(Breakpoint.fromWidth(0), Breakpoint.xs);
      expect(Breakpoint.fromWidth(599), Breakpoint.xs);
      expect(Breakpoint.fromWidth(600), Breakpoint.sm);
      expect(Breakpoint.fromWidth(904), Breakpoint.sm);
      expect(Breakpoint.fromWidth(905), Breakpoint.md);
      expect(Breakpoint.fromWidth(1239), Breakpoint.md);
      expect(Breakpoint.fromWidth(1240), Breakpoint.lg);
      expect(Breakpoint.fromWidth(1439), Breakpoint.lg);
      expect(Breakpoint.fromWidth(1440), Breakpoint.xl);
      expect(Breakpoint.fromWidth(2560), Breakpoint.xl);
    });

    test('shape predicates are consistent with bucket', () {
      expect(Breakpoint.xs.isMobile, isTrue);
      expect(Breakpoint.md.isTablet, isTrue);
      expect(Breakpoint.lg.isDesktop, isTrue);
      expect(Breakpoint.lg.isAtLeastMd, isTrue);
      expect(Breakpoint.xs.isAtLeastLg, isFalse);
    });
  });
}
