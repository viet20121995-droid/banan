import 'package:banan_domain/banan_domain.dart';
import 'package:test/test.dart';

/// Mirrors the catalog entries the backend serves for the five wards formed
/// from old District 12 — the exact `oldArea` strings matter for search.
const q12 = <HcmWard>[
  HcmWard(
    code: 'dong-hung-thuan',
    name: 'Phường Đông Hưng Thuận',
    oldArea: 'Tân Thới Nhất, Tân Hưng Thuận, Đông Hưng Thuận · Quận 12',
  ),
  HcmWard(
    code: 'trung-my-tay',
    name: 'Phường Trung Mỹ Tây',
    oldArea: 'Tân Chánh Hiệp, Trung Mỹ Tây · Quận 12',
  ),
  HcmWard(
    code: 'tan-thoi-hiep',
    name: 'Phường Tân Thới Hiệp',
    oldArea: 'Hiệp Thành, Tân Thới Hiệp · Quận 12',
  ),
  HcmWard(
    code: 'thoi-an',
    name: 'Phường Thới An',
    oldArea: 'Thạnh Xuân, Thới An · Quận 12',
  ),
  HcmWard(
    code: 'an-phu-dong',
    name: 'Phường An Phú Đông',
    oldArea: 'Thạnh Lộc, An Phú Đông · Quận 12',
  ),
];

const others = <HcmWard>[
  HcmWard(
    code: 'sai-gon',
    name: 'Phường Sài Gòn',
    oldArea: 'Bến Nghé, Đa Kao, Nguyễn Thái Bình · Q1',
  ),
  HcmWard(
    code: 'cau-ong-lanh',
    name: 'Phường Cầu Ông Lãnh',
    oldArea: 'Nguyễn Cư Trinh, Cầu Kho, Cô Giang · Q1',
    legacyCodes: ['cau-kho'],
  ),
];

List<String> hits(String query) => [...q12, ...others]
    .where((w) => wardMatchesQuery(w, query))
    .map((w) => w.code)
    .toList();

void main() {
  group('wardMatchesQuery', () {
    test('"Quận 12" and "Q12" both return all five Q12 wards', () {
      for (final q in ['Quận 12', 'quận 12', 'Q12', 'q12', 'quan 12']) {
        expect(
          hits(q).toSet(),
          {
            'dong-hung-thuan',
            'trung-my-tay',
            'tan-thoi-hiep',
            'thoi-an',
            'an-phu-dong',
          },
          reason: 'query "$q" must hit exactly the Q12 wards',
        );
      }
    });

    test('matches an old constituent ward name, with or without diacritics',
        () {
      expect(hits('Thạnh Lộc'), ['an-phu-dong']);
      expect(hits('thanh loc'), ['an-phu-dong']);
    });

    test('matches the new ward name diacritic-insensitively', () {
      expect(hits('dong hung thuan'), ['dong-hung-thuan']);
      expect(hits('Đông Hưng Thuận'), ['dong-hung-thuan']);
    });

    test('old inner-district shorthand still works', () {
      expect(hits('Q1').toSet(), {'sai-gon', 'cau-ong-lanh'});
      expect(hits('Quận 1').toSet(), {'sai-gon', 'cau-ong-lanh'});
    });

    test('empty query matches everything', () {
      expect(hits('').length, q12.length + others.length);
    });
  });

  group('HcmWard.matchesCode', () {
    test('resolves a legacy alias carried by a saved address', () {
      const ward = HcmWard(
        code: 'cau-ong-lanh',
        name: 'Phường Cầu Ông Lãnh',
        legacyCodes: ['cau-kho'],
      );
      expect(ward.matchesCode('cau-ong-lanh'), isTrue);
      expect(ward.matchesCode('cau-kho'), isTrue);
      expect(ward.matchesCode('sai-gon'), isFalse);
      expect(ward.matchesCode(null), isFalse);
    });
  });
}
