-- CANDO-216: Add 'signature_required' to Shipment Table as a Boolean
--            also add a new log table to log any changes to the field.
--            Also adds a new Finance Flag in the 'flag' table to alert
--            Online Fraud that there may be something to investigate.

BEGIN WORK;

--
-- Add the new Field and Log Table
--

-- add the column
ALTER TABLE shipment
    ADD COLUMN signature_required BOOLEAN DEFAULT TRUE
;

-- add the log table
CREATE TABLE log_shipment_signature_required (
    id              SERIAL PRIMARY KEY,
    shipment_id     INTEGER REFERENCES shipment(id) NOT NULL,
    new_state       BOOLEAN NOT NULL,
    date            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    operator_id     INTEGER REFERENCES operator(id) NOT NULL
)
;

ALTER TABLE log_shipment_signature_required OWNER TO postgres;
GRANT ALL ON TABLE log_shipment_signature_required TO postgres;
GRANT ALL ON TABLE log_shipment_signature_required TO www;
GRANT ALL ON TABLE log_shipment_signature_required_id_seq TO postgres;
GRANT ALL ON TABLE log_shipment_signature_required_id_seq TO www;


--
-- Add the new Finance Flag
--

INSERT INTO flag ( description, flag_type_id ) VALUES (
    'Delivery Signature Opt Out',
    (
        SELECT  id
        FROM    flag_type
        WHERE   description = 'Finance'
    )
)
;


COMMIT WORK;
