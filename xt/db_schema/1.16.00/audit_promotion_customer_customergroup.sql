-- This function's intent is to update the audit table for
-- promotion.customer_customergroup every time an entry is added or remove

BEGIN;

    -- Create new columns
    ALTER TABLE promotion.customer_customergroup
        ADD created timestamp with time zone
            DEFAULT CURRENT_TIMESTAMP NOT NULL
    ;

    ALTER TABLE promotion.customer_customergroup
        ADD created_by integer REFERENCES operator(id)
    ;

    ALTER TABLE promotion.customer_customergroup
        ADD modified timestamp with time zone
            DEFAULT CURRENT_TIMESTAMP NOT NULL
    ;

    ALTER TABLE promotion.customer_customergroup
        ADD modified_by integer REFERENCES operator(id)
    ;

    -- Set default value for rows that are null
    UPDATE promotion.customer_customergroup SET created_by = 1
        WHERE created_by IS NULL
    ;
    UPDATE promotion.customer_customergroup SET modified_by = 1
        WHERE modified_by IS NULL
    ;

    -- Set not null constraint
    ALTER TABLE promotion.customer_customergroup
        ALTER COLUMN created_by SET NOT NULL
    ;

    ALTER TABLE promotion.customer_customergroup
        ALTER COLUMN modified_by SET NOT NULL
    ;

    -- Create audit table
    CREATE TABLE audit.promotion_customer_customergroup (
        action              varchar(6),

        id                  integer,
        customer_id         integer,
        customergroup_id    integer,
        website_id          integer,
        created             timestamp with time zone,
        created_by          integer,
        modified            timestamp with time zone,
        modified_by         integer
    );
    ALTER TABLE audit.promotion_customer_customergroup OWNER TO www;

    -- Create function to update audit table
    CREATE OR REPLACE FUNCTION audit.promotion_customer_customergroup_trigger() RETURNS
        trigger AS $$
    DECLARE
    BEGIN

        IF (TG_OP = 'DELETE') THEN
            OLD.modified := NOW();
            IF (OLD.modified_by = NULL) THEN
                OLD.modified_by := 1;
            END IF;
            INSERT INTO audit.promotion_customer_customergroup VALUES ( TG_OP, OLD.* );
            RETURN OLD;
        ELSE
            INSERT INTO audit.promotion_customer_customergroup VALUES ( TG_OP, NEW.* );
            RETURN NEW;
        END IF;


        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    -- Create trigger to call function
    CREATE TRIGGER promotion_customer_customergroup_audit_tgr AFTER INSERT OR UPDATE OR DELETE
    ON promotion.customer_customergroup
        FOR EACH ROW EXECUTE PROCEDURE audit.promotion_customer_customergroup_trigger();

COMMIT;
