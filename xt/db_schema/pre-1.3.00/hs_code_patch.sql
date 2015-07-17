-- Purpose:
--  Adding a boolean flag to hs code table to allow us to switch old codes off without deleting them

BEGIN;

alter table hs_code add column active boolean default true;

-- Do it!
COMMIT;
