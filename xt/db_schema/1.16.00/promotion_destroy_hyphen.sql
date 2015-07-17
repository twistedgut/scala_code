-- this addresses: http://animal/browse/XPM-164
BEGIN WORK;
    -- fix function ownership
    ALTER FUNCTION create_coupon_code() OWNER TO www;


    -- replace the existing function
    CREATE OR REPLACE FUNCTION create_coupon_code() RETURNS
        trigger AS $$
    BEGIN
        NEW.code := NEW.prefix || NEW.suffix;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
COMMIT;
