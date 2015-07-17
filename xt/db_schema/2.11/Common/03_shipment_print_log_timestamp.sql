-- Add default timestamp to shipment_print_log
BEGIN;
    ALTER TABLE shipment_print_log ALTER COLUMN date SET DEFAULT now();
COMMIT;
