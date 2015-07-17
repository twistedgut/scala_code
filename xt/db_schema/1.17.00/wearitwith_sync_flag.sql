
BEGIN;

alter table recommended_product add column auto_set boolean default false;


COMMIT;