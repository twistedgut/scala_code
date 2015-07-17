BEGIN;

alter table product add column watch boolean default false;

COMMIT;
