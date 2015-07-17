-- DCA-2674: Default date will be more useful if it's the time the
-- statement runs, not the transaction timestamp.

BEGIN;

alter table allocation_item_log
    alter date set default statement_timestamp();

COMMIT;

