-- CANDO-7910: Create Customer Service Attribute Log Table
--
-- Create a table to log the last time a succesful update was pushed to the
-- customer service (Seaview) for an arbitrary attribute (BOSH).

BEGIN WORK;


-- TABLE service_attribute_type
--
-- Create and populate a table to hold the types of attribute log entries. At
-- present, only 'Customer Value' is supported.

CREATE TABLE service_attribute_type (
    id      SERIAL PRIMARY KEY,
    type    VARCHAR(50) UNIQUE
);

INSERT INTO service_attribute_type (
    type
) VALUES (
    'Customer Value'
);

ALTER TABLE public.service_attribute_type OWNER TO postgres;
GRANT ALL ON TABLE public.service_attribute_type TO www;
GRANT ALL ON SEQUENCE public.service_attribute_type_id_seq TO www;


-- TABLE customer_service_attribute_log
--
-- Create a table to record when an attribute in BOSH within the customer
-- service (Seaview) was last updated.

CREATE TABLE customer_service_attribute_log (
    id                          SERIAL PRIMARY KEY,
    customer_id                 INTEGER NOT NULL REFERENCES customer(id),
    service_attribute_type_id   INTEGER NOT NULL REFERENCES service_attribute_type(id),
    last_sent                   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    --
    CONSTRAINT                  customer_service_attribute_log_unique
                                    UNIQUE ( customer_id, service_attribute_type_id )
);

ALTER TABLE public.customer_service_attribute_log OWNER TO postgres;
GRANT ALL ON TABLE public.customer_service_attribute_log TO www;
GRANT ALL ON SEQUENCE public.customer_service_attribute_log_id_seq TO www;


COMMIT;
