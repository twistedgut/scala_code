BEGIN;

alter table quantity_operation_log drop constraint quantity_operation_log_location_id_fkey;

COMMIT;
