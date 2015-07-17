BEGIN;
    alter table operator_preferences add column packing_printer char(20);
COMMIT;
