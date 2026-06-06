-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- AlterEnum (new enum value committed here; used only in a later migration)
ALTER TYPE "MembershipTier" ADD VALUE 'BRONZE';

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "gender" "Gender";
