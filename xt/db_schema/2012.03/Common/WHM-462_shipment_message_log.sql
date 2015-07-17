-- Add a table to log shipment messages

BEGIN;
    CREATE TABLE shipment_message_log (
        id SERIAL PRIMARY KEY,
        shipment_id INTEGER REFERENCES public.shipment NOT NULL,
        operator_id INTEGER REFERENCES public.operator NOT NULL,
        message_type text NOT NULL,
        date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    ALTER TABLE shipment_message_log OWNER TO www;
    CREATE INDEX ix_shipment_message_log_shipment_id ON shipment_message_log(shipment_id);
COMMIT;
