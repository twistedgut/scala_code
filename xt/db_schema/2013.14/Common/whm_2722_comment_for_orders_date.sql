-- Another type of date column was just added ("order_created_in_xt_date"), but
-- it makes the existing 'date' column less clear. Which date does it now represent?

BEGIN;

COMMENT ON COLUMN orders.date IS 'Date the order was created on the public website';

COMMIT;
