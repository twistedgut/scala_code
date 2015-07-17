-- this patch adds indexes to columns we discover we are using for searching
-- and ordering
BEGIN;

    CREATE INDEX idx_list_name ON list.list(name);

COMMIT;
