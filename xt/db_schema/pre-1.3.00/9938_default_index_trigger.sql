-- this is a factoring out of Jason's useful function/trigger for making the
-- idx of a product default to the id (PK)

BEGIN;

SELECT 'Create default index trigger';
CREATE OR REPLACE FUNCTION public.default_index_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_id                INTEGER := NULL;
    v_idx               INTEGER := NULL;
    v_table             TEXT := NULL;
    v_schema            TEXT := NULL;
BEGIN

    v_id := NEW.id;
    v_idx := NEW.idx;
    v_table := TG_RELNAME;

    SELECT INTO
        v_schema schemaname
    FROM
        pg_catalog.pg_tables
    WHERE
        tablename = v_table;

    IF v_idx IS NULL THEN
        v_idx := v_id;

        EXECUTE ''UPDATE '' || v_schema || ''.'' || v_table
            || '' SET idx = '' || v_idx
            || '' WHERE id = '' || v_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION ''Trigger cannot update record'';
        END IF;

    END IF;
    

    RETURN NEW;
END;
' LANGUAGE plpgsql;


COMMENT ON FUNCTION public.default_index_trigger() IS
    'This serves to create default ordering for reference tables';

COMMIT;
