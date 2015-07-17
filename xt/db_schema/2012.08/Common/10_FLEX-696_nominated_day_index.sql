BEGIN;


CREATE OR REPLACE FUNCTION timestamp_to_date(TIMESTAMP WITH TIME ZONE) 
RETURNS DATE AS $$
DECLARE
    v_timestamp ALIAS FOR $1;
    v_date DATE := NULL;
BEGIN

    IF v_timestamp = NULL THEN
        RETURN NULL;
    END IF;

    v_date := date_trunc('day', v_timestamp);
    RETURN v_date;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE INDEX shipment_nominated_dispatch_time_date_idx
    ON shipment (timestamp_to_date(nominated_dispatch_time));


COMMIT;
