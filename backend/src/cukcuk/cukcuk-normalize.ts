import { createHmac } from 'node:crypto';

/// Datasets pulled from the CukCuk Open Platform. Kept as plain strings so
/// records can be stored generically (`CukcukRecord.kind`).
export const CUKCUK_KINDS = [
  'branches',
  'categories',
  'items',
  'customers',
  'invoices',
  'orders',
] as const;
export type CukcukKind = (typeof CUKCUK_KINDS)[number];

export function isCukcukKind(v: unknown): v is CukcukKind {
  return typeof v === 'string' && (CUKCUK_KINDS as readonly string[]).includes(v);
}

/// Login signature per MISA docs: HMAC-SHA256 (hex) of the JSON login
/// payload `{AppID, Domain, LoginTime}` with the connection's secret key.
export function cukcukSignature(
  secret: string,
  payload: { AppID: string; Domain: string; LoginTime: string },
): string {
  return createHmac('sha256', secret).update(JSON.stringify(payload)).digest('hex');
}

export interface NormalizedRecord {
  externalId: string;
  label: string | null;
  branchId: string | null;
  modifiedAt: Date | null;
}

const str = (v: unknown): string | null =>
  typeof v === 'string' && v.trim() !== '' ? v.trim() : typeof v === 'number' ? String(v) : null;

/// Pull the identity fields every dataset needs out of a raw CukCuk row.
/// Field names differ per dataset (Id / RefId, Name / RefNo …), so each is a
/// candidate list; the raw row is stored untouched next to these.
export function normalizeRecord(kind: CukcukKind, row: Record<string, unknown>): NormalizedRecord {
  const externalId = str(row.Id) ?? str(row.RefId) ?? str(row.Code);
  if (!externalId) throw new Error(`CukCuk ${kind} row without Id/RefId/Code`);
  const label =
    kind === 'invoices'
      ? str(row.RefNo)
      : kind === 'orders'
        ? (str(row.No) ?? str(row.Code))
        : (str(row.Name) ?? str(row.Code));
  const branchId = str(row.BranchId) ?? (kind === 'branches' ? externalId : null);
  const modifiedRaw =
    row.ModifiedDate ?? row.LastUpdatedAt ?? row.RefDate ?? row.Date ?? row.CreatedDate;
  const modified = typeof modifiedRaw === 'string' ? new Date(modifiedRaw) : null;
  return {
    externalId,
    label,
    branchId,
    modifiedAt: modified && !Number.isNaN(modified.getTime()) ? modified : null,
  };
}

/// "0867540939" ⇐ "+84 867 540 939" / "84867540939" / "0867-540-939".
export function normalizePhone(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  let digits = raw.replace(/\D/g, '');
  if (digits.startsWith('84') && digits.length >= 11) digits = `0${digits.slice(2)}`;
  return digits.length >= 9 ? digits : null;
}
