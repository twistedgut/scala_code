-- Add a table to audit variant measurements

BEGIN;
    CREATE TABLE variant_measurements_log (
        id SERIAL PRIMARY KEY,
        variant_id INTEGER REFERENCES public.variant NOT NULL,
        operator_id INTEGER REFERENCES public.operator NOT NULL,
        note text NOT NULL,
        date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    ALTER TABLE variant_measurements_log OWNER TO www;
    CREATE INDEX ix_variant_measurements_log_variant_id ON variant_measurements_log(variant_id);
COMMIT;
