BEGIN;

ALTER TABLE shipment_print_log DROP CONSTRAINT print_log_shipment_id_fkey,
    ADD FOREIGN KEY (shipment_id) REFERENCES shipment(id) DEFERRABLE;

COMMIT;
