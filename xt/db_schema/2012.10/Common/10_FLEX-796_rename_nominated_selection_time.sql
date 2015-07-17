BEGIN;

ALTER TABLE shipment RENAME nominated_selection_time
    TO nominated_earliest_selection_time;


COMMIT;
