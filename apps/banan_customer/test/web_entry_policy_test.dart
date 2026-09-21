import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web entry disables referrers before loading payment navigation code', () {
    final html = File('web/index.html').readAsStringSync();
    final policies = RegExp(
      r'<meta\s+name="referrer"\s+content="([^"]+)"\s*/?>',
    ).allMatches(html).toList();

    expect(policies, hasLength(1));
    expect(policies.single.group(1), 'no-referrer');
    expect(policies.single.start, lessThan(html.indexOf('<script')));
  });
}
