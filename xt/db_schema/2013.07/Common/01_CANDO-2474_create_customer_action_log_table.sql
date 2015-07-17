-- CANDO-2474: Create a table to record actions taken on a customer record.

BEGIN WORK;

-- Create Tables

CREATE TABLE customer_action_type (
    id      serial PRIMARY KEY,
    type    CHARACTER VARYING(50) UNIQUE NOT NULL
);

CREATE TABLE public.customer_action (
    id                      serial PRIMARY KEY,
    customer_id             INTEGER NOT NULL REFERENCES customer(id),
    operator_id             INTEGER NOT NULL REFERENCES operator(id),
    customer_action_type_id INTEGER NOT NULL REFERENCES customer_action_type(id),
    date_created            TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Populate Tables

INSERT INTO customer_action_type (
    type
) VALUES (
    'New High Value'
);

-- Grant Permissions

ALTER TABLE public.customer_action
    OWNER TO postgres;

GRANT ALL
    ON TABLE public.customer_action
    TO www;

GRANT ALL
    ON SEQUENCE public.customer_action_id_seq
    TO www;

ALTER TABLE public.customer_action_type
    OWNER TO postgres;

GRANT ALL
    ON TABLE public.customer_action_type
    TO www;

GRANT ALL
    ON SEQUENCE public.customer_action_type_id_seq
    TO www;

-- Done

COMMIT WORK;
