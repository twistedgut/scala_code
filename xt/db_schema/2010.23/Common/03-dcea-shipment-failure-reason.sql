BEGIN;

ALTER TABLE shipment_item ADD COLUMN qc_failure_reason TEXT;

COMMIT;
