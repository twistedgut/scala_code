-- This patch file addresses UPL-105; http://animal/browse/UPL-105
--
-- Priority Items require functionality to set a priority date

BEGIN;

    ALTER TABLE product.list_item
        ADD COLUMN target_date timestamp with time zone
    ;

COMMIT;
