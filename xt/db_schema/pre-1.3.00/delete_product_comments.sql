BEGIN;

alter table product_comment add column deleted boolean default false;

COMMIT;
