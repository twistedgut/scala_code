-- this fixes the glitch where "last modified" doesn't actually reflect the
-- last modified time - doh!

BEGIN;
    CREATE OR REPLACE FUNCTION audit.promotion_detail_trigger() RETURNS
        trigger AS $$
    DECLARE
        v_table     TEXT := '''';
    BEGIN

        -- FIXME: factor this out into a mapping from RELID->audit.sumtable
        v_table := 'audit.promotion';

        -- FIXME: build dynamic table name
        IF (TG_OP = 'DELETE') THEN
            -- FIXME: application user until we've decide how we do it
            OLD.last_modified_by := 1;
            -- make sure we know when it was last updated
            OLD.last_modified := NOW();
            INSERT INTO audit.promotion_detail VALUES ( TG_OP, OLD.* );
            RETURN OLD;
        ELSE
            -- make sure we know when it was last updated
            NEW.last_modified := NOW();
            -- insert the audit record
            INSERT INTO audit.promotion_detail VALUES ( TG_OP, NEW.* );
            RETURN NEW;
        END IF;


        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
COMMIT;
