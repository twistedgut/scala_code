-- Purpose:
--  Alter the lyris customer_segment table to support all the lovely new data
--  IMPORTANT: Run against the LYRIS database, not XT. That's lmdatabase on uklmdb1
--  Bad things will happen if this is run against the XT database

BEGIN;

ALTER TABLE customer_segment ADD COLUMN xt_recency integer NOT NULL DEFAULT 0;
ALTER TABLE customer_segment ADD COLUMN xt_potential_initial integer NOT NULL DEFAULT 0;
ALTER TABLE customer_segment ADD COLUMN xt_potential_order1 integer NOT NULL DEFAULT 0;
ALTER TABLE customer_segment ADD COLUMN xt_primary integer NOT NULL DEFAULT 0;

COMMIT;

