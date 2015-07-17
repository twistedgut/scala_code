-- DCEA-1239 DCEA-1242
-- Add 'old_container' text field to orphan_item table
-- Be able to display tote history

BEGIN;

    ALTER TABLE public.orphan_item
    	ADD column old_container_id VARCHAR(255)
    ;

COMMIT;

