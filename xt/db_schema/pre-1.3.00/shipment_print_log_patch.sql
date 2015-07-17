-- Purpose:
--  Remove the dependency on the printer table from the shipment_print_log table
--  Now that we are going to store printer data in the config file this will make more sense.
--
-- Warning: This update will take some time to run.

BEGIN;

ALTER TABLE shipment_print_log DROP CONSTRAINT print_log_printer_id_fkey;
ALTER TABLE shipment_print_log RENAME COLUMN printer_id TO printer_name;
ALTER TABLE shipment_print_log ALTER COLUMN printer_name TYPE VARCHAR(255);

UPDATE shipment_print_log SET printer_name = p.name FROM printer p WHERE p.id = printer_name;

COMMIT;