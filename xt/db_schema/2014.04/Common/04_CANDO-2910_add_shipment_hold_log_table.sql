-- CANDO-2910: Add 'shipment_hold_log' table so there
--             can be a history of Shipment Holds

BEGIN WORK;

CREATE TABLE shipment_hold_log (
    id                          SERIAL PRIMARY KEY,
    shipment_id                 INTEGER NOT NULL REFERENCES shipment(id),
    shipment_hold_reason_id     INTEGER NOT NULL REFERENCES shipment_hold_reason(id),
    comment                     TEXT NOT NULL,
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE shipment_hold_log OWNER TO postgres;
GRANT ALL ON TABLE shipment_hold_log TO www;
GRANT ALL ON SEQUENCE shipment_hold_log_id_seq TO www;

CREATE INDEX idx_shipment_hold_log_shipment_id ON shipment_hold_log(shipment_id);

COMMIT WORK;
