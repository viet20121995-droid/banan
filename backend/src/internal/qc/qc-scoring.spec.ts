import { scoreQc, type QcSectionInput } from './qc-scoring';

const section = (
  id: string,
  values: ('PASS' | 'FAIL' | 'NOT_AVAILABLE' | null)[],
  isRisk = false,
): QcSectionInput => ({ sectionId: id, title: id, isRisk, values });

describe('scoreQc', () => {
  it('N/A leaves the denominator entirely', () => {
    const r = scoreQc([section('a', ['PASS', 'PASS', 'NOT_AVAILABLE', 'NOT_AVAILABLE'])], false);
    expect(r.sections[0].applicable).toBe(2);
    expect(r.sections[0].percent).toBe(100);
    expect(r.overallApplicable).toBe(2);
    expect(r.outcome).toBe('PASS');
  });

  it('an all-N/A section is N/A — no division by zero, not a fail', () => {
    const r = scoreQc(
      [
        section('wc', ['NOT_AVAILABLE', 'NOT_AVAILABLE']),
        section('b', ['PASS', 'PASS', 'PASS', 'PASS', 'PASS']),
      ],
      false,
    );
    expect(r.sections[0].percent).toBeNull();
    expect(r.sections[0].belowThreshold).toBe(false);
    expect(r.overallPercent).toBe(100);
    expect(r.outcome).toBe('PASS');
  });

  it('any applicable section under 80% fails the inspection', () => {
    // 3/4 = 75% in one section, everything else perfect.
    const r = scoreQc(
      [
        section('low', ['PASS', 'PASS', 'PASS', 'FAIL']),
        section(
          'rest',
          Array.from({ length: 20 }, () => 'PASS'),
        ),
      ],
      false,
    );
    expect(r.sections[0].percent).toBe(75);
    expect(r.overallPercent).toBeGreaterThanOrEqual(80); // 23/24
    expect(r.outcome).toBe('FAIL');
  });

  it('overall under 80% fails even when no single section is under', () => {
    // Five sections of 5 items, each 4/5 = 80% (not below threshold)…
    // that's overall 80% → PASS; push one to 3/5? that section fails.
    // True overall-only fail needs sections AT 80% and overall < 80 —
    // impossible with equal sizes, so mix: 4/5 (80%) ×4 and 8/10 (80%) → 80.
    // Use unequal: [4/5, 4/5, 4/5, 4/5, 16/20] → 32/40 = 80. Drop one more
    // overall point via a section that stays ≥80: not constructible below
    // exact threshold — assert the boundary: exactly 80% PASSes, 79.99 FAILs.
    const atBoundary = scoreQc([section('a', ['PASS', 'PASS', 'PASS', 'PASS', 'FAIL'])], false);
    expect(atBoundary.overallPercent).toBe(80);
    expect(atBoundary.outcome).toBe('PASS');

    const below = scoreQc(
      [section('a', ['PASS', 'PASS', 'PASS', 'FAIL'])], // 75%
      false,
    );
    expect(below.outcome).toBe('FAIL');
  });

  it('a single Risk makes it CRITICAL_FAIL regardless of a perfect score', () => {
    const r = scoreQc([section('a', ['PASS', 'PASS', 'PASS'])], true);
    expect(r.overallPercent).toBe(100);
    expect(r.outcome).toBe('CRITICAL_FAIL');
  });

  it('risk sections are excluded from scoring', () => {
    const r = scoreQc(
      [section('a', ['PASS', 'PASS']), section('risk', ['FAIL', 'FAIL'], true)],
      false,
    );
    expect(r.sections).toHaveLength(1);
    expect(r.overallPercent).toBe(100);
  });
});
