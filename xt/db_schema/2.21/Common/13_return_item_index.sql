BEGIN;
CREATE INDEX return_item_return_id_index ON return_item (return_id);
CREATE INDEX return_return_satus_id_index ON return (return_status_id);
COMMIT;
