-- Add a created timestamp column to sticky page table

BEGIN;
    ALTER TABLE operator.sticky_page
        ADD COLUMN created timestamp with time zone NOT NULL DEFAULT now();
COMMIT;
