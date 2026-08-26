/**
 * Pure Mystery Shopper scoring — used by approve(), the PDF and the report
 * email.
 *
 * - Each SCORED group has a weight; total template weight = 100.
 * - Within a group: YES = 1, NO = 0, NOT_AVAILABLE leaves the group's
 *   denominator. groupScore = yes / applicable × weight. A group whose
 *   every question is N/A contributes its full weight to neither the
 *   numerator nor the maximum — the total is normalised over the applicable
 *   weight so the result still reads out of 100.
 * - Any CRITICAL question answered YES ⇒ CRITICAL_FAIL regardless of score.
 */

export type MsAnswerValueLike = 'YES' | 'NO' | 'NOT_AVAILABLE';

export interface MsSectionInput {
  sectionId: string;
  code: string;
  title: string;
  kind: 'SCORED' | 'CRITICAL';
  weight: number;
  values: (MsAnswerValueLike | null)[];
}

export interface MsSectionScore {
  sectionId: string;
  code: string;
  title: string;
  weight: number;
  yesCount: number;
  noCount: number;
  naCount: number;
  applicable: number;
  /** Earned points after weighting; null when the whole group is N/A. */
  score: number | null;
}

export interface MsResult {
  sections: MsSectionScore[];
  /** Weighted score normalised to a 0–100 scale over applicable weight. */
  totalScore: number | null;
  criticalFail: boolean;
  outcome: 'PASS' | 'CRITICAL_FAIL';
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

export function scoreMs(sections: MsSectionInput[]): MsResult {
  const scored: MsSectionScore[] = [];
  let earned = 0;
  let applicableWeight = 0;
  let criticalFail = false;

  for (const s of sections) {
    if (s.kind === 'CRITICAL') {
      if (s.values.some((v) => v === 'YES')) criticalFail = true;
      continue;
    }
    const yesCount = s.values.filter((v) => v === 'YES').length;
    const noCount = s.values.filter((v) => v === 'NO').length;
    const naCount = s.values.filter((v) => v === 'NOT_AVAILABLE').length;
    const applicable = yesCount + noCount;
    const score = applicable === 0 ? null : round1((yesCount / applicable) * s.weight);
    scored.push({
      sectionId: s.sectionId,
      code: s.code,
      title: s.title,
      weight: s.weight,
      yesCount,
      noCount,
      naCount,
      applicable,
      score,
    });
    if (score != null) {
      earned += score;
      applicableWeight += s.weight;
    }
  }

  const totalScore = applicableWeight === 0 ? null : round1((earned / applicableWeight) * 100);

  return {
    sections: scored,
    totalScore,
    criticalFail,
    outcome: criticalFail ? 'CRITICAL_FAIL' : 'PASS',
  };
}
