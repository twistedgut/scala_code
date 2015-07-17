
-- FLEX-669 - Patcher applies things twice after move
--
-- Modify existing rows in dbadmin.applied_patch so filename ignores
-- which version the file is in.

BEGIN;



UPDATE dbadmin.applied_patch
    SET filename = regexp_replace(filename, E'db_schema/\\d+\\.\\d+/', '');



COMMIT;

