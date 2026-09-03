/**
 * Branch inboxes for new-order email alerts. The merchant web app is often
 * left logged in on an iPad, where web push never fires — so every order is
 * ALSO emailed to the fulfilling branch's mailbox. Ops addresses receive
 * every order regardless of branch.
 *
 * Keyed by Store.slug (stable, admin-visible). A store missing here simply
 * gets no branch email — ops still receives everything.
 */
export const STORE_ALERT_EMAILS: Record<string, string> = {
  'banan-ngo-quang-huy': 'info.banancafe@gmail.com',
  'banan-truong-sa': 'bananphunhuan@gmail.com',
  'banan-su-van-hanh': 'banansuvanhanh@gmail.com',
  'banan-le-thanh-ton': 'bananlethanhton@gmail.com',
};

export const OPS_ALERT_EMAILS = ['operationmanager@banancakes.com', 'ntyen104@gmail.com'];

/** Recipients of the daily site-traffic report (MetricsService cron). */
export const DAILY_REPORT_EMAILS = [
  'operationmanager@banancakes.com',
  'ducnguyen@vestav.com',
  'marketingbanan@vesta-group.org',
];

/** Branch inbox (when mapped) + the always-on ops addresses. */
export function storeAlertRecipients(storeSlug: string | null | undefined): string[] {
  const branch = storeSlug ? STORE_ALERT_EMAILS[storeSlug] : undefined;
  return branch ? [branch, ...OPS_ALERT_EMAILS] : [...OPS_ALERT_EMAILS];
}
