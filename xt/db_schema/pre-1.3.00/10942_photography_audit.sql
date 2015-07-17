-- Auditing for photography images
--   Chisel Wright (September 2007)

BEGIN;

    CREATE TABLE audit.photography_image (
        action              varchar(6),
        id                  integer,
        product_id          integer,
        idx                 integer,
        image_status_id     integer,
        image_label_id      integer,
        created             timestamp with time zone,
        last_modified       timestamp with time zone,
        created_by          integer,
        last_modified_by    integer
    );
    GRANT ALL ON audit.photography_image TO www;


    CREATE OR REPLACE FUNCTION audit.photography_image_trigger() RETURNS
        trigger AS $$
    DECLARE
        v_table     TEXT := '''';
    BEGIN

        -- FIXME: factor this out into a mapping from RELID->audit.sumtable
        v_table := 'photography.image';

        -- FIXME: build dynamic table name
        IF (TG_OP = 'DELETE') THEN
            OLD.last_modified    := NOW();
            OLD.last_modified_by := 1; -- FIXME Jason will solve this hack :)
            INSERT INTO audit.photography_image VALUES ( TG_OP, OLD.* );
            RETURN OLD;
        ELSE
            INSERT INTO audit.photography_image VALUES ( TG_OP, NEW.* );
            RETURN NEW;
        END IF;


        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER audit_photography_image AFTER INSERT OR UPDATE OR DELETE
    ON photography.image
        FOR EACH ROW EXECUTE PROCEDURE audit.photography_image_trigger();

COMMIT;
