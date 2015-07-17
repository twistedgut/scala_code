-- Description:
-- Adds column to stock_order table
-- so retail can confirm when an order is complete.

BEGIN;

alter table stock_order add column confirmed boolean;
alter table stock_order alter column confirmed set default false;
update stock_order set confirmed = false;
alter table stock_order alter column confirmed set not null;

COMMIT;

