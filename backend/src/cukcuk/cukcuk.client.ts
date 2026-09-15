import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';

import { cukcukSignature } from './cukcuk-normalize';

/**
 * Thin client for the MISA CukCuk Open Platform (graphapi.cukcuk.vn).
 * Credentials come from the environment — CUKCUK_DOMAIN (the restaurant's
 * CukCuk subdomain), CUKCUK_APP_ID and CUKCUK_SECRET_KEY (from CukCuk →
 * Thiết lập → Kết nối API). Unset = integration disabled, every call throws
 * a 503 the UI can show.
 *
 * The API is pull-only (no webhooks): login returns a bearer token + company
 * code, then each dataset is paged with `POST …/paging { Page, Limit,
 * LastSyncDate }` or listed with a GET.
 */
@Injectable()
export class CukcukClient {
  private readonly logger = new Logger(CukcukClient.name);
  private token: { value: string; companyCode: string; expiresAt: number } | null = null;

  get configured(): boolean {
    return Boolean(
      process.env.CUKCUK_DOMAIN && process.env.CUKCUK_APP_ID && process.env.CUKCUK_SECRET_KEY,
    );
  }

  get domain(): string | null {
    return process.env.CUKCUK_DOMAIN ?? null;
  }

  private get baseUrl(): string {
    return (process.env.CUKCUK_BASE_URL ?? 'https://graphapi.cukcuk.vn').replace(/\/$/, '');
  }

  private async login(): Promise<void> {
    if (!this.configured) {
      throw new ServiceUnavailableException({
        code: 'CUKCUK_NOT_CONFIGURED',
        message: 'Chưa cấu hình CUKCUK_DOMAIN / CUKCUK_APP_ID / CUKCUK_SECRET_KEY trên server.',
      });
    }
    const payload = {
      AppID: process.env.CUKCUK_APP_ID as string,
      Domain: process.env.CUKCUK_DOMAIN as string,
      LoginTime: new Date().toISOString(),
    };
    const res = await fetch(`${this.baseUrl}/api/account/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...payload,
        SignatureInfo: cukcukSignature(process.env.CUKCUK_SECRET_KEY as string, payload),
      }),
    });
    const body = (await res.json().catch(() => null)) as {
      Success?: boolean;
      Data?: { AccessToken?: string; CompanyCode?: string };
      ErrorType?: number;
      ErrorMessage?: string;
    } | null;
    if (!res.ok || !body?.Success || !body.Data?.AccessToken) {
      this.logger.warn(`CukCuk login failed: HTTP ${res.status} ${body?.ErrorMessage ?? ''}`);
      throw new ServiceUnavailableException({
        code: 'CUKCUK_LOGIN_FAILED',
        message: `Đăng nhập CukCuk thất bại: ${body?.ErrorMessage ?? `HTTP ${res.status}`}`,
      });
    }
    this.token = {
      value: body.Data.AccessToken,
      companyCode: body.Data.CompanyCode ?? '',
      // Tokens last ~24h; refresh well before that.
      expiresAt: Date.now() + 20 * 60 * 60 * 1000,
    };
  }

  private async request<T>(
    method: 'GET' | 'POST',
    path: string,
    body?: unknown,
    retry = true,
  ): Promise<T> {
    if (!this.token || this.token.expiresAt < Date.now()) await this.login();
    const t = this.token as NonNullable<typeof this.token>;
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${t.value}`,
        CompanyCode: t.companyCode,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 401 && retry) {
      this.token = null;
      return this.request<T>(method, path, body, false);
    }
    const json = (await res.json().catch(() => null)) as {
      Success?: boolean;
      Data?: T;
      ErrorType?: number;
      ErrorMessage?: string;
    } | null;
    if (!res.ok || json?.Success === false) {
      throw new ServiceUnavailableException({
        code: 'CUKCUK_REQUEST_FAILED',
        message: `CukCuk ${method} ${path}: ${json?.ErrorMessage ?? `HTTP ${res.status}`}`,
      });
    }
    return (json?.Data ?? json) as T;
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path);
  }

  post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('POST', path, body);
  }

  /// Walk a `…/paging` endpoint until a short page. `Limit` 100 is the
  /// documented max. The callback receives each page so callers can persist
  /// incrementally instead of holding a whole year of invoices in memory.
  async pageAll(
    path: string,
    body: Record<string, unknown>,
    onPage: (rows: Record<string, unknown>[]) => Promise<void>,
  ): Promise<number> {
    const limit = 100;
    let page = 1;
    let total = 0;
    for (;;) {
      const data = await this.post<unknown>(path, { ...body, Page: page, Limit: limit });
      const rows = Array.isArray(data)
        ? (data as Record<string, unknown>[])
        : (((data as { Data?: unknown })?.Data as Record<string, unknown>[] | undefined) ?? []);
      if (rows.length === 0) break;
      await onPage(rows);
      total += rows.length;
      // Hard stop far above any real dataset (5000 pages = 500k rows).
      if (rows.length < limit || page >= 5000) break;
      page += 1;
    }
    return total;
  }
}
