-- Push-notification device tokens (FCM). Lets the backend target a
-- specific app surface — web push, iOS APNs, Android — for the same user.

CREATE TYPE "DevicePlatform" AS ENUM ('WEB', 'IOS', 'ANDROID');

CREATE TABLE "DeviceToken" (
  "id"        TEXT NOT NULL,
  "userId"    TEXT NOT NULL,
  "platform"  "DevicePlatform" NOT NULL,
  "token"     TEXT NOT NULL,
  "lastSeen"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DeviceToken_token_key" ON "DeviceToken"("token");
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");

ALTER TABLE "DeviceToken"
  ADD CONSTRAINT "DeviceToken_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
