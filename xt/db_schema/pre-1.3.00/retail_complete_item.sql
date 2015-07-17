-- Description:
-- Adds column to stock_order_item table
-- so retail can confirm when an order is complete.
-- Removes column from stock_order table.

BEGIN;

alter table stock_order_item add column confirmed boolean;
alter table stock_order_item alter column confirmed set default false;
update stock_order_item set confirmed = false;
alter table stock_order_item alter column confirmed set not null;

alter table stock_order drop column confirmed;

alter table purchase_order add column confirmed boolean;
alter table purchase_order alter column confirmed set default false;
update purchase_order set confirmed = false;
alter table purchase_order alter column confirmed set not null;

alter table purchase_order add column confirmed_operator_id integer;
alter table purchase_order alter column confirmed_operator_id set default 0;
update purchase_order set confirmed_operator_id = 0;
alter table purchase_order alter column confirmed_operator_id set not null;

COMMIT;

