-- Add an index to rtv_quantity(status_id)

BEGIN;
    CREATE INDEX ix_rtv_quantity_status_id ON rtv_quantity(status_id);
COMMIT;
