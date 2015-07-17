BEGIN;

-- PROVIDE GENUINE A GENUINE AUDIT LOG OF QUANTITY CHANGES

-- log_stock should have an entry for every database change.
-- however it doesn't due to a small design flaw. it doesn't
-- use database triggers.

-- hopefully this new table + splunk logging should allow us
-- to find out why log_stock isn't being updated correctly.

CREATE TABLE quantity_operation_log (
    id serial primary key,
    quantity_id integer not null,  -- refers to quantity.id but not a foreign key.
    variant_id integer not null references variant(id),   -- value of the record after adjustment
    location_id integer not null references location(id),  -- value of the record after adjustment
    quantity integer not null,     -- value of the record after adjustment
    operation text not null,       -- table operation causing adjustment
    delta integer not null,        -- what the difference was
    created timestamp with time zone not null default statement_timestamp() -- time it occurred
);

GRANT SELECT ON TABLE quantity_operation_log TO www;

CREATE INDEX idx_quantity_operation_created ON quantity_operation_log(created);

CREATE OR REPLACE FUNCTION quantity_operation_log_update() RETURNS trigger AS '
DECLARE
    v_delta integer := NULL;
BEGIN

    IF (TG_OP = ''INSERT'') THEN
        insert into quantity_operation_log (
            quantity_id,
            variant_id,
            location_id,
            quantity,
            operation,
            delta
        ) values (
            NEW.id,
            NEW.variant_id,
            NEW.location_id,
            NEW.quantity,
            TG_OP,
            NEW.quantity
        );

    END IF;

    IF (TG_OP = ''UPDATE'') THEN

        v_delta = NEW.quantity - OLD.quantity;

        insert into quantity_operation_log (
            quantity_id,
            variant_id,
            location_id,
            quantity,
            operation,
            delta
        ) values (
            NEW.id,
            NEW.variant_id,
            NEW.location_id,
            NEW.quantity,
            TG_OP,
            v_delta
        );

    END IF;

    IF (TG_OP = ''DELETE'') THEN

        insert into quantity_operation_log (
            quantity_id,
            variant_id,
            location_id,
            quantity,
            operation,
            delta
        ) values (
            OLD.id,
            OLD.variant_id,
            OLD.location_id,
            0, -- delete implies zero stock
            TG_OP,
            (OLD.quantity * -1)
        );
    END IF;

    RETURN NEW;

END;
' LANGUAGE plpgsql;

CREATE TRIGGER tgr_quantity_operation_log AFTER INSERT OR UPDATE OR DELETE ON quantity FOR EACH ROW EXECUTE PROCEDURE quantity_operation_log_update();

COMMIT;
