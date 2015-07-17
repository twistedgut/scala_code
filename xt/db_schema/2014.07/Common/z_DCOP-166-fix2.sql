BEGIN;

alter table quantity_operation_log drop constraint quantity_operation_log_variant_id_fkey;

COMMIT;
