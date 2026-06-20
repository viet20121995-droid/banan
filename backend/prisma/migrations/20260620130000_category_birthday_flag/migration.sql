-- Birthday-cake detection moves from a Collection slug to a designated Category.
ALTER TABLE "Category" ADD COLUMN "isBirthdayCakeCategory" BOOLEAN NOT NULL DEFAULT false;
