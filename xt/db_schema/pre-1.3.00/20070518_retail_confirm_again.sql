BEGIN;

alter table stock_order_item drop column confirmed;

alter table stock_order add column confirmed boolean not null default false;

COMMIT;


