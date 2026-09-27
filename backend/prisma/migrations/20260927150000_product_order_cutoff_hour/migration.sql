-- Same-day cut-off: orders placed at/after this Vietnam hour are fulfilled from the next day.
ALTER TABLE "Product" ADD COLUMN "orderCutoffHour" INTEGER;
