-- Gift-with-purchase campaign type (order over X gets one gift product free).
ALTER TYPE "CampaignType" ADD VALUE IF NOT EXISTS 'GIFT_WITH_PURCHASE';
