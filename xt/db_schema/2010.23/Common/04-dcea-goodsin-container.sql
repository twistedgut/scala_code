BEGIN;

ALTER TABLE stock_process
 ADD COLUMN container VARCHAR(255)
;

COMMIT;
