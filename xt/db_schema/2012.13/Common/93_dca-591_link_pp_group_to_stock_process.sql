-- DCA-591: Link putaway_prep_group table to stock_process

BEGIN;

ALTER TABLE putaway_prep_group ADD COLUMN stock_process_id INTEGER REFERENCES stock_process(id) DEFERRABLE;

COMMIT;
