-- DC2's patcher table appears to be missing a crucial constraint
-- this causes us to not have 'created' timestamps
BEGIN;

    -- first force all patches without a timestamp to have one (we pick a date, 2 weeks in the past)
    UPDATE      dbadmin.applied_patch SET created=NOW() - interval '2 weeks' WHERE created IS NULL;

    -- then apply the constraints - first we deny nulls
    ALTER TABLE dbadmin.applied_patch ALTER COLUMN created SET NOT NULL;
    -- then we force the default timestamp
    ALTER TABLE dbadmin.applied_patch ALTER COLUMN created SET DEFAULT NOW();
COMMIT;
