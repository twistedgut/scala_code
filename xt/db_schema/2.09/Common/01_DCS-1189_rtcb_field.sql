-- Add 'real_time_carrier_booking' field to 'shipment' table
-- and populate existing records to FALSE.
-- Also create 'log_shipment_rtcb_state' table for field.

BEGIN WORK;

ALTER TABLE shipment ADD COLUMN real_time_carrier_booking BOOLEAN DEFAULT FALSE;

UPDATE shipment
    SET real_time_carrier_booking = FALSE
;

ALTER TABLE shipment ALTER COLUMN real_time_carrier_booking SET NOT NULL
;

COMMIT WORK;

BEGIN WORK;

CREATE TABLE log_shipment_rtcb_state (
    id SERIAL NOT NULL,
    shipment_id INTEGER NOT NULL REFERENCES shipment(id),
    new_state BOOLEAN NOT NULL,
    date_changed TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT ('now'::text)::timestamp(6) WITH TIME ZONE,
    operator_id INTEGER NOT NULL REFERENCES operator(id),
    reason_for_change TEXT NOT NULL,
    CONSTRAINT log_shipment_rtcb_state_pkey PRIMARY KEY (id)
)
;
ALTER TABLE log_shipment_rtcb_state OWNER TO postgres;
GRANT ALL ON TABLE log_shipment_rtcb_state TO postgres;
GRANT ALL ON TABLE log_shipment_rtcb_state TO www;

GRANT ALL ON TABLE log_shipment_rtcb_state_id_seq TO postgres;
GRANT ALL ON TABLE log_shipment_rtcb_state_id_seq TO www;

COMMIT WORK;
