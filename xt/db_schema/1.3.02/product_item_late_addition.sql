-- this file creates requires tables and columns for the new
-- functionality required to alter the status of image comments

BEGIN;

    ALTER TABLE product.list_item
        ADD COLUMN late_addition BOOLEAN DEFAULT FALSE NOT NULL;

COMMIT;
