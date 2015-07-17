-- Purpose:
--  Add a varchar "info" field to stock_tranfer
BEGIN;

ALTER TABLE stock_transfer ADD COLUMN info varchar(30) null;

COMMIT;