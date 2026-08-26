import { scoreMs, type MsSectionInput } from './ms-scoring';

const scored = (
  id: string,
  weight: number,
  values: ('YES' | 'NO' | 'NOT_AVAILABLE' | null)[],
): MsSectionInput => ({
  sectionId: id,
  code: id,
  title: id,
  kind: 'SCORED',
  weight,
  values,
});

const critical = (values: ('YES' | 'NO' | null)[]): MsSectionInput => ({
  sectionId: 'crit',
  code: 'CRIT',
  title: 'crit',
  kind: 'CRITICAL',
  weight: 0,
  values,
});

describe('scoreMs', () => {
  it('weights groups and totals out of 100', () => {
    const r = scoreMs([
      scored('a', 40, ['YES', 'YES']),
      scored('b', 60, ['YES', 'NO']), // half of 60
      critical(['NO']),
    ]);
    expect(r.sections.find((s) => s.code === 'a')?.score).toBe(40);
    expect(r.sections.find((s) => s.code === 'b')?.score).toBe(30);
    expect(r.totalScore).toBe(70);
    expect(r.outcome).toBe('PASS');
  });

  it('N/A leaves the denominator of its own group only', () => {
    const r = scoreMs([scored('f', 15, ['YES', 'YES', 'YES', 'YES', 'NOT_AVAILABLE'])]);
    // 4/4 applicable → full 15 points.
    expect(r.sections[0].score).toBe(15);
    expect(r.totalScore).toBe(100);
  });

  it('a fully-N/A group is removed and the total renormalises to /100', () => {
    const r = scoreMs([
      scored('a', 50, ['YES']),
      scored('b', 50, ['NOT_AVAILABLE', 'NOT_AVAILABLE']),
    ]);
    expect(r.sections.find((s) => s.code === 'b')?.score).toBeNull();
    // Only 50 weight applicable, all earned → still reads 100/100.
    expect(r.totalScore).toBe(100);
  });

  it('any critical YES overrides the score with CRITICAL_FAIL', () => {
    const r = scoreMs([scored('a', 100, ['YES', 'YES']), critical(['NO', 'YES'])]);
    expect(r.totalScore).toBe(100);
    expect(r.criticalFail).toBe(true);
    expect(r.outcome).toBe('CRITICAL_FAIL');
  });
});
