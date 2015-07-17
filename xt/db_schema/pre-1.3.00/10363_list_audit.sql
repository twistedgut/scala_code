-- Auditing for lists
--  This file contains the schema changes regarding auditing to lists
--  Jason Tang (August 2007)

BEGIN;

SELECT 'adding list auditing';


CREATE TABLE audit.list_list (
    action              VARCHAR(6),
    id                  INTEGER,
    name                VARCHAR(255),
    type_id             INTEGER,
    status_id           INTEGER,
    created             TIMESTAMP WITH TIME ZONE,
    last_modified       TIMESTAMP WITH TIME ZONE,
    created_by          INTEGER,
    last_modified_by    INTEGER,
    due                 DATE
);

CREATE TABLE audit.list_list_item (
    action              VARCHAR(6),
    id                  INTEGER,
    list_id             INTEGER,
    created             TIMESTAMP WITH TIME ZONE,
    last_modified       TIMESTAMP WITH TIME ZONE,
    created_by          INTEGER,
    last_modified_by    INTEGER
);



CREATE OR REPLACE FUNCTION audit.list_list_trigger() RETURNS
    trigger AS $$
DECLARE
    v_table     TEXT := '''';
BEGIN

    -- FIXME: factor this out into a mapping from RELID->audit.sumtable
    v_table := 'audit.list_list';

    -- FIXME: build dynamic table name
    IF (TG_OP = 'DELETE') THEN
        OLD.last_modified := NOW();
        -- FIXME: application user until we've decide how we do it
        OLD.last_modified_by := 1;
        INSERT INTO audit.list_list VALUES ( TG_OP, OLD.* );
        RETURN OLD;
    ELSE
        INSERT INTO audit.list_list VALUES ( TG_OP, NEW.* );
        RETURN NEW;
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER list_tgr AFTER INSERT OR UPDATE OR DELETE
ON list.list
    FOR EACH ROW EXECUTE PROCEDURE audit.list_list_trigger();



CREATE OR REPLACE FUNCTION audit.list_item_trigger() RETURNS
    trigger AS $$
DECLARE
    v_table     TEXT := '''';
BEGIN

    -- FIXME: factor this out into a mapping from RELID->audit.sumtable
    v_table := 'audit.list_list';

    -- FIXME: build dynamic table name
    IF (TG_OP = 'DELETE') THEN
        OLD.last_modified := NOW();
        -- FIXME: application user until we've decide how we do it
        OLD.last_modified_by := 1;
        INSERT INTO audit.list_list_item VALUES ( TG_OP, OLD.* );
        RETURN OLD;
    ELSE
        INSERT INTO audit.list_list_item VALUES ( TG_OP, NEW.* );
        RETURN NEW;
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER list_item_tgr AFTER INSERT OR UPDATE OR DELETE
ON list.item
    FOR EACH ROW EXECUTE PROCEDURE audit.list_item_trigger();



COMMIT;

