-- We do joins and searches on this column, so an index would be useful

BEGIN;
    CREATE INDEX log_delivery_delivery_id_idx ON log_delivery(delivery_id);
COMMIT;
