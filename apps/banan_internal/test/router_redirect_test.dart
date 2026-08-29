import 'package:banan_domain/banan_domain.dart';
import 'package:banan_internal/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

String? redirect(String location, {Role? role}) =>
    internalRedirect(uri: Uri.parse(location), role: role);

void main() {
  group('public routes', () {
    for (final loc in ['/', '/ms/create', '/f', '/f/some-token', '/survey']) {
      test('$loc is reachable for guest, trainee and admin', () {
        expect(redirect(loc), isNull);
        expect(redirect(loc, role: Role.trainee), isNull);
        expect(redirect(loc, role: Role.admin), isNull);
      });
    }
  });

  group('survey admin area', () {
    const adminPages = [
      '/survey/reports',
      '/survey/editor',
      '/survey/link',
      '/survey/rewards',
      '/survey/cases',
    ];

    test('guest bounces to login WITH returnTo', () {
      for (final loc in adminPages) {
        expect(redirect(loc), '/login?returnTo=${Uri.encodeComponent(loc)}', reason: loc);
      }
    });

    test('TRAINEE and other staff are blocked', () {
      for (final loc in adminPages) {
        expect(redirect(loc, role: Role.trainee), '/wrong-app', reason: loc);
        expect(redirect(loc, role: Role.merchantOwner), '/wrong-app', reason: loc);
      }
    });

    test('ADMIN passes everywhere', () {
      for (final loc in adminPages) {
        expect(redirect(loc, role: Role.admin), isNull, reason: loc);
      }
    });
  });

  group('guest', () {
    test('protected areas bounce to login WITH returnTo', () {
      expect(redirect('/qc'), '/login?returnTo=%2Fqc');
      expect(redirect('/schedule'), '/login?returnTo=%2Fschedule');
      expect(redirect('/ms'), '/login?returnTo=%2Fms');
      expect(redirect('/training'), '/login?returnTo=%2Ftraining');
      expect(redirect('/qc/insp-1'), '/login?returnTo=%2Fqc%2Finsp-1');
    });

    test('login itself stays put', () => expect(redirect('/login'), isNull));
    test('wrong-app for a guest goes home', () => expect(redirect('/wrong-app'), '/'));
  });

  group('TRAINEE', () {
    test('training is allowed', () => expect(redirect('/training', role: Role.trainee), isNull));
    test('QC / schedule / admin MS are blocked', () {
      expect(redirect('/qc', role: Role.trainee), '/wrong-app');
      expect(redirect('/schedule', role: Role.trainee), '/wrong-app');
      expect(redirect('/ms', role: Role.trainee), '/wrong-app');
      expect(redirect('/ms/some-id', role: Role.trainee), '/wrong-app');
    });
  });

  group('ADMIN', () {
    test('every area is allowed', () {
      for (final loc in ['/qc', '/ms', '/ms/some-id', '/training', '/schedule']) {
        expect(redirect(loc, role: Role.admin), isNull, reason: loc);
      }
    });
  });

  group('other staff roles', () {
    test('merchant hitting QC lands on wrong-app', () {
      expect(redirect('/qc', role: Role.merchantOwner), '/wrong-app');
      expect(redirect('/training', role: Role.kitchenManager), '/wrong-app');
    });
  });

  group('login returnTo', () {
    test('after login the user continues to what they picked', () {
      expect(redirect('/login?returnTo=%2Fqc', role: Role.admin), '/qc');
      expect(redirect('/login?returnTo=%2Ftraining', role: Role.trainee), '/training');
    });

    test('no returnTo → home', () {
      expect(redirect('/login', role: Role.admin), '/');
    });

    test('open-redirect attempts are neutralised to home', () {
      for (final evil in [
        'https://evil.example',
        '//evil.example/qc',
        'javascript:alert(1)',
        'qc', // not app-absolute
      ]) {
        expect(
          redirect('/login?returnTo=${Uri.encodeComponent(evil)}', role: Role.admin),
          '/',
          reason: evil,
        );
      }
    });
  });

  group('sanitizeReturnTo', () {
    test('accepts same-app absolute paths only', () {
      expect(sanitizeReturnTo('/qc'), '/qc');
      expect(sanitizeReturnTo('/ms/abc?x=1'), '/ms/abc?x=1');
      expect(sanitizeReturnTo(null), isNull);
      expect(sanitizeReturnTo(''), isNull);
      expect(sanitizeReturnTo('//host'), isNull);
      expect(sanitizeReturnTo('http://x'), isNull);
      expect(sanitizeReturnTo('relative/path'), isNull);
    });
  });
}
