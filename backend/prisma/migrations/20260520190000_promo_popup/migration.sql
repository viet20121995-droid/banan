-- Singleton promotional popup shown to every customer visiting the menu.
-- Admin edits the body / image / CTA / countdown via a dedicated screen.
-- Bumping `version` re-triggers the popup for all customers (clients
-- compare to the last-seen version in localStorage).
CREATE TABLE "PromoPopup" (
  "id"               TEXT NOT NULL,
  "isActive"         BOOLEAN NOT NULL DEFAULT FALSE,
  "title"            TEXT NOT NULL DEFAULT 'Chào mừng đến với Banan',
  "body"             TEXT NOT NULL DEFAULT '',
  "imageUrl"         TEXT,
  "ctaLabel"         TEXT,
  "ctaUrl"           TEXT,
  -- 0 = no auto-close (customer must click X). Else closes after N seconds
  -- with a visible countdown.
  "countdownSeconds" INTEGER NOT NULL DEFAULT 0,
  -- Bumped by the admin to force-resurface the popup for everyone — even
  -- for customers who previously dismissed the prior version.
  "version"          INTEGER NOT NULL DEFAULT 1,
  "updatedAt"        TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "PromoPopup_pkey" PRIMARY KEY ("id")
);

-- Seed the singleton — inactive by default, admin enables once configured.
INSERT INTO "PromoPopup" ("id", "title", "body", "updatedAt")
VALUES ('default', 'Chào mừng đến với Banan', 'Khám phá thực đơn các loại bánh ngọt Nhật Bản tươi mỗi ngày.', CURRENT_TIMESTAMP);
