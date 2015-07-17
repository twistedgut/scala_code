-- This script:
--   * added order line heading and text to detail table
BEGIN WORK;

    ALTER TABLE promotion.detail
        ADD order_line_heading varchar(30)
    ;

    ALTER TABLE promotion.detail
        ADD order_line_text varchar(75)
    ;

    ALTER TABLE promotion.detail
        ADD created timestamp with time zone DEFAULT CURRENT_TIMESTAMP
    ;


    ALTER TABLE promotion.detail
        ADD created_by integer references operator(id)
    ;
    UPDATE promotion.detail SET created_by=
        (SELECT id FROM operator WHERE name='Application' AND username='')
    ;
    ALTER TABLE promotion.detail
        ALTER COLUMN created_by SET NOT NULL
    ;



    ALTER TABLE promotion.detail
        ADD last_modified timestamp with time zone DEFAULT CURRENT_TIMESTAMP
    ;

    ALTER TABLE promotion.detail
        ADD last_modified_by integer references operator(id)
    ;
    UPDATE promotion.detail SET last_modified_by=
        (SELECT id FROM operator WHERE name='Application' AND username='')
    ;
    ALTER TABLE promotion.detail
        ALTER COLUMN last_modified_by SET NOT NULL
    ;

    -- add missing link from coupon to promotion
    ALTER TABLE promotion.coupon
        ADD COLUMN promotion_detail_id integer NOT NULL
            references promotion.detail(id)
    ;


    --
    -- auditing tables
    --
    CREATE TABLE audit.promotion_detail (
        action                  VARCHAR(6),
        last_modified           timestamp with time zone,
        last_modified_by        integer,

        id                      integer,
        visible_id              character varying(20),
        title                   character varying(50),
        start_date              timestamp with time zone,
        end_date                timestamp with time zone,
        target_city_id          integer,
        offer_type              character varying(50),
        discount_percentage     integer,
        discount_pounds         integer,
        discount_euros          integer,
        discount_dollars        integer,
        coupon_prefix           character varying(8),
        coupon_target_id        integer,
        coupon_restriction_id   integer,
        email_required          boolean,
        price_group_id          integer,
        basket_trigger_pounds   integer,
        basket_trigger_euros    integer,
        basket_trigger_dollars  integer,
        enabled                 boolean,
        order_line_heading      character varying(30),
        order_line_text         character varying(75),
        created                 timestamp with time zone,
        created_by              integer
    );

    CREATE OR REPLACE FUNCTION audit.promotion_detail_trigger() RETURNS
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
            INSERT INTO audit.promotion_detail VALUES ( TG_OP, OLD.* );
            RETURN OLD;
        ELSE
            INSERT INTO audit.promotion_detail VALUES ( TG_OP, NEW.* );
            RETURN NEW;
        END IF;


        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER promotion_detail_audit_tgr AFTER INSERT OR UPDATE OR DELETE
    ON promotion.detail
        FOR EACH ROW EXECUTE PROCEDURE audit.promotion_detail_trigger();

    --
    -- need to work out what we've done wrong with the trigger
    --
    alter table promotion.detail disable TRIGGER promotion_detail_audit_tgr;
COMMIT;
