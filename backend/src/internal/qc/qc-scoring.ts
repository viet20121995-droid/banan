import { QC_PASS_THRESHOLD_PERCENT } from './qc-template-data';

/**
 * Pure QC scoring — the single source of truth used by complete(), the PDF,
 * the report email and the comparison endpoint. Rules from the paper form:
 *
 * - Each normal item: PASS = 1, FAIL = 0, NOT_AVAILABLE leaves the
 *   denominator entirely.
 * - sectionPercent = PASS / (PASS + FAIL) × 100. A section with zero
 *   applicable items is N/A — it neither fails nor divides by zero.
 * - overallPercent uses the same formula over ALL normal sections.
 * - CRITICAL_FAIL when any RISK occurred; else FAIL when overall < 80% or
 *   any applicable section < 80%; else PASS. Maximums are always computed
 *   from the actual items — never hard-coded (the paper form's printed /40
 *   contradicts its own visible items).
 */

export type QcAnswerValueLike = 'PASS' | 'FAIL' | 'NOT_AVAILABLE';

export interface QcSectionInput {
  sectionId: string;
  title: string;
  isRisk: boolean;
  /** One entry per item: the recorded answer (null = unanswered). */
  values: (QcAnswerValueLike | null)[];
}

export interface QcSectionScore {
  sectionId: string;
  title: string;
  passCount: number;
  failCount: number;
  naCount: number;
  applicable: number;
  /** null when the whole section is N/A (applicable = 0). */
  percent: number | null;
  /** Only meaningful when percent != null. */
  belowThreshold: boolean;
}

export interface QcResult {
  sections: QcSectionScore[];
  overallPass: number;
  overallApplicable: number;
  /** null when nothing at all was applicable. */
  overallPercent: number | null;
  riskOccurred: boolean;
  outcome: 'PASS' | 'FAIL' | 'CRITICAL_FAIL';
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export function scoreQc(sections: QcSectionInput[], riskOccurred: boolean): QcResult {
  const scored: QcSectionScore[] = [];
  let overallPass = 0;
  let overallApplicable = 0;

  for (const s of sections) {
    if (s.isRisk) continue;
    const passCount = s.values.filter((v) => v === 'PASS').length;
    const failCount = s.values.filter((v) => v === 'FAIL').length;
    const naCount = s.values.filter((v) => v === 'NOT_AVAILABLE').length;
    const applicable = passCount + failCount;
    const percent = applicable === 0 ? null : round2((passCount / applicable) * 100);
    scored.push({
      sectionId: s.sectionId,
      title: s.title,
      passCount,
      failCount,
      naCount,
      applicable,
      percent,
      belowThreshold: percent != null && percent < QC_PASS_THRESHOLD_PERCENT,
    });
    overallPass += passCount;
    overallApplicable += applicable;
  }

  const overallPercent =
    overallApplicable === 0 ? null : round2((overallPass / overallApplicable) * 100);

  let outcome: QcResult['outcome'];
  if (riskOccurred) {
    outcome = 'CRITICAL_FAIL';
  } else if (
    (overallPercent != null && overallPercent < QC_PASS_THRESHOLD_PERCENT) ||
    scored.some((s) => s.belowThreshold)
  ) {
    outcome = 'FAIL';
  } else {
    outcome = 'PASS';
  }

  return {
    sections: scored,
    overallPass,
    overallApplicable,
    overallPercent,
    riskOccurred,
    outcome,
  };
}
