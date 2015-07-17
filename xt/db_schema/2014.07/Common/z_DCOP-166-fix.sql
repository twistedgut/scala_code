BEGIN;

grant select, insert on quantity_operation_log to www;
grant all on sequence quantity_operation_log_id_seq to www;

COMMIT;
