/**
 * Pure warning computation for a weekly schedule. Warnings NEVER block or
 * mutate anything — the admin's data stays exactly as entered.
 *
 * Detected:
 * - the same person (roster id, or identical free-text name) in two shifts
 *   whose hours overlap on the same day — including across branches;
 * - shifts with no one assigned on a given day… reported once per
 *   (shift, day) with nobody;
 * - inactive roster people still being scheduled.
 */

export interface WarnShift {
  id: string;
  storeId: string;
  storeName: string;
  label: string;
  startTime: string;
  endTime: string;
  assignments: {
    id: string;
    dayOfWeek: number;
    personId: string | null;
    personName: string | null;
    personActive: boolean | null;
    freeName: string | null;
  }[];
}

export interface ScheduleWarning {
  kind: 'OVERLAP' | 'EMPTY_SHIFT' | 'INACTIVE_PERSON';
  message: string;
  dayOfWeek?: number;
  shiftIds: string[];
}

const DAYS = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

function minutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

/** Overnight shifts (end <= start) are treated as ending at 24:00 for
 *  overlap purposes — good enough for a bakery closing at 22:30. */
function range(shift: { startTime: string; endTime: string }): [number, number] {
  const s = minutes(shift.startTime);
  const e = minutes(shift.endTime);
  return [s, e > s ? e : 24 * 60];
}

function overlaps(a: [number, number], b: [number, number]): boolean {
  return a[0] < b[1] && b[0] < a[1];
}

export function computeScheduleWarnings(shifts: WarnShift[]): ScheduleWarning[] {
  const warnings: ScheduleWarning[] = [];

  // Empty shifts + inactive people.
  for (const shift of shifts) {
    for (let day = 0; day < 7; day++) {
      if (!shift.assignments.some((a) => a.dayOfWeek === day)) {
        warnings.push({
          kind: 'EMPTY_SHIFT',
          dayOfWeek: day,
          shiftIds: [shift.id],
          message: `${shift.storeName} · ${shift.label} (${DAYS[day]}): chưa có ai.`,
        });
      }
    }
    for (const a of shift.assignments) {
      if (a.personId && a.personActive === false) {
        warnings.push({
          kind: 'INACTIVE_PERSON',
          dayOfWeek: a.dayOfWeek,
          shiftIds: [shift.id],
          message: `${a.personName ?? 'Nhân sự'} đã ngưng làm việc nhưng vẫn được xếp ${shift.storeName} · ${shift.label} (${DAYS[a.dayOfWeek]}).`,
        });
      }
    }
  }

  // Overlaps: same identity, same day, intersecting hours.
  interface Slot {
    key: string;
    display: string;
    day: number;
    shift: WarnShift;
  }
  const slots: Slot[] = [];
  for (const shift of shifts) {
    for (const a of shift.assignments) {
      const key = a.personId
        ? `id:${a.personId}`
        : a.freeName
          ? `name:${a.freeName.trim().toLowerCase()}`
          : null;
      if (!key) continue;
      slots.push({
        key,
        display: a.personName ?? a.freeName ?? '?',
        day: a.dayOfWeek,
        shift,
      });
    }
  }
  const seenPairs = new Set<string>();
  for (let i = 0; i < slots.length; i++) {
    for (let j = i + 1; j < slots.length; j++) {
      const a = slots[i];
      const b = slots[j];
      if (a.key !== b.key || a.day !== b.day || a.shift.id === b.shift.id) continue;
      if (!overlaps(range(a.shift), range(b.shift))) continue;
      const pairKey = [a.key, a.day, [a.shift.id, b.shift.id].sort().join('|')].join('#');
      if (seenPairs.has(pairKey)) continue;
      seenPairs.add(pairKey);
      const crossStore = a.shift.storeId !== b.shift.storeId;
      warnings.push({
        kind: 'OVERLAP',
        dayOfWeek: a.day,
        shiftIds: [a.shift.id, b.shift.id],
        message: crossStore
          ? `${a.display} bị xếp ở HAI chi nhánh trùng giờ (${DAYS[a.day]}): ${a.shift.storeName} ${a.shift.label} và ${b.shift.storeName} ${b.shift.label}.`
          : `${a.display} bị xếp trùng giờ (${DAYS[a.day]}): ${a.shift.label} và ${b.shift.label} tại ${a.shift.storeName}.`,
      });
    }
  }
  return warnings;
}
