-- Add a table to log shipment box status changes

BEGIN;
    CREATE TABLE shipment_box_log(
        id serial primary key,
        shipment_box_id text not null,
        skus text[] not null,
        action text not null,
        operator_id int not null references operator(id),
        timestamp timestamptz not null default now()
    );
    CREATE INDEX ix_shipment_box_log_shipment_box_id ON shipment_box_log(shipment_box_id);
    ALTER TABLE shipment_box_log OWNER TO www;

    COMMENT ON TABLE shipment_box_log IS 'Log shipment box status changes';

    COMMENT ON COLUMN shipment_box_log.skus IS 'SKUs in box at time of logging';
    COMMENT ON COLUMN shipment_box_log.action IS 'Action performed on the shipment box';
    COMMENT ON COLUMN shipment_box_log.operator_id IS 'ID of operator who performed the action';
    COMMENT ON COLUMN shipment_box_log.timestamp IS 'Time at which the update was performed';
COMMIT;
