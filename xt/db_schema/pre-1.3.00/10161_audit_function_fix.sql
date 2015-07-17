-- Auditing triggers and functions
--  Removal of debugging message
--  Jason Tang (June 2007)

BEGIN;

SELECT 'Create audit trigger';
CREATE OR REPLACE FUNCTION audit.product_trigger() RETURNS
    trigger AS $$
DECLARE
    -- Variables
    v_operator_id     INTEGER := NULL;
    v_table_id        INTEGER := NULL;
    v_product_id      INTEGER := NULL;
    v_action_id       INTEGER := NULL;
    v_comment         TEXT := '''';
    v_pushed_to_live  BOOLEAN := FALSE;
    v_operator_name   TEXT := '''';
BEGIN

    SELECT INTO v_action_id id FROM audit.action
        WHERE table_name = TG_RELNAME AND action = TG_OP;

    IF v_action_id IS NULL THEN
        RAISE NOTICE
            'audit_trigger: Undefined action for table: % ; action: %',
            TG_RELNAME, TG_OP;
    END IF;

    -- INSERT and UPDATE use NEW
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        v_operator_id       := NEW.operator_id;
        v_table_id          := NEW.id;
        v_product_id        := v_table_id;

        IF (NOT TG_RELNAME = 'product') THEN
            v_product_id := NEW.product_id;
        END IF;

    -- remaining option is DELETE
    ELSE
        v_operator_id       := OLD.operator_id;
        v_table_id          := OLD.id;
        v_product_id        := v_table_id;

        IF (NOT TG_RELNAME = 'product') THEN
            v_product_id := OLD.product_id;
        END IF;

    END IF;


    v_comment := audit.build_comment(v_action_id, v_operator_id);

    INSERT INTO audit.product (
        operator_id, table_id, product_id, action_id, comment, pushed_to_live
    ) VALUES (
        v_operator_id, v_table_id, v_product_id, v_action_id, v_comment,
        v_pushed_to_live
    );


    IF (TG_OP = 'DELETE') THEN

        RETURN OLD;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


COMMIT;


