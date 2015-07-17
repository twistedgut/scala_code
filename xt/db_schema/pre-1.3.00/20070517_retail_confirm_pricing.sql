BEGIN;

alter table price_default add column complete boolean default false;
alter table price_default add column complete_by_operator_id int references operator(id);

COMMIT;
