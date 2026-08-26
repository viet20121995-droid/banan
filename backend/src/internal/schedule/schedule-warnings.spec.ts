import { computeScheduleWarnings, type WarnShift } from './schedule-warnings';

function shift(
  id: string,
  storeId: string,
  hours: [string, string],
  assignments: WarnShift['assignments'],
): WarnShift {
  return {
    id,
    storeId,
    storeName: `Store ${storeId}`,
    label: `Ca ${id}`,
    startTime: hours[0],
    endTime: hours[1],
    assignments,
  };
}

const person = (
  day: number,
  personId: string | null,
  freeName: string | null = null,
  active = true,
): WarnShift['assignments'][number] => ({
  id: `${personId ?? freeName}-${day}`,
  dayOfWeek: day,
  personId,
  personName: personId ? `Person ${personId}` : null,
  personActive: personId ? active : null,
  freeName,
});

describe('computeScheduleWarnings', () => {
  it('flags the same person overlapping across two branches', () => {
    const w = computeScheduleWarnings([
      shift('1', 'A', ['09:00', '14:00'], [person(0, 'p1')]),
      shift('2', 'B', ['13:00', '18:00'], [person(0, 'p1')]),
    ]);
    const overlap = w.filter((x) => x.kind === 'OVERLAP');
    expect(overlap).toHaveLength(1);
    expect(overlap[0].message).toContain('HAI chi nhánh');
  });

  it('no overlap when shifts touch back-to-back or days differ', () => {
    const w = computeScheduleWarnings([
      shift('1', 'A', ['09:00', '14:00'], [person(0, 'p1'), person(1, 'p2')]),
      shift('2', 'A', ['14:00', '18:00'], [person(0, 'p1')]),
      shift('3', 'B', ['09:00', '14:00'], [person(2, 'p2')]),
    ]);
    expect(w.filter((x) => x.kind === 'OVERLAP')).toHaveLength(0);
  });

  it('matches free-text names case-insensitively for overlaps', () => {
    const w = computeScheduleWarnings([
      shift('1', 'A', ['09:00', '14:00'], [person(3, null, 'Phương ')]),
      shift('2', 'A', ['13:00', '18:00'], [person(3, null, 'phương')]),
    ]);
    expect(w.filter((x) => x.kind === 'OVERLAP')).toHaveLength(1);
  });

  it('reports empty shift-days and inactive people, never blocking', () => {
    const w = computeScheduleWarnings([
      shift('1', 'A', ['09:00', '14:00'], [person(0, 'p1', null, false)]),
    ]);
    // 6 empty days (day 0 has someone) + 1 inactive warning.
    expect(w.filter((x) => x.kind === 'EMPTY_SHIFT')).toHaveLength(6);
    expect(w.filter((x) => x.kind === 'INACTIVE_PERSON')).toHaveLength(1);
  });

  it('overnight end (22:00 → 22:30 vs 18:00) still overlaps correctly', () => {
    const w = computeScheduleWarnings([
      shift('1', 'A', ['18:00', '22:30'], [person(5, 'p9')]),
      shift('2', 'A', ['21:00', '02:00'], [person(5, 'p9')]),
    ]);
    expect(w.filter((x) => x.kind === 'OVERLAP')).toHaveLength(1);
  });
});
