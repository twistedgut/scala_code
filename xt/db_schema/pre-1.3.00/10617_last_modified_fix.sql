-- this function assumes there are the following fields in your table
-- id (serial), last_modified (timestamp)

BEGIN;


CREATE OR REPLACE FUNCTION public.update_last_modified_time() RETURNS
    trigger AS $$
BEGIN
    NEW.last_modified := current_timestamp;

    IF NEW.last_modified IS NULL THEN
        RAISE EXCEPTION '% unable to update last_modified field', NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_last_modified_time() IS
    'Updates the last_modified field with current timestamp';

COMMIT;
