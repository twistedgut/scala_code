-- Add a table to log shipment_item container changes

BEGIN;
    CREATE TABLE shipment_item_container_log (
        id SERIAL PRIMARY KEY,
        shipment_item_id INTEGER NOT NULL REFERENCES shipment_item(id),
        -- No reference here, so we can delete containers if required without
        -- breaking referential integrity
        old_container_id text,
        new_container_id text,
        operator_id INTEGER NOT NULL REFERENCES operator(id),
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE shipment_item_container_log OWNER TO www;
    CREATE INDEX ix_shipment_item_id ON shipment_item_container_log(shipment_item_id);
COMMIT;
