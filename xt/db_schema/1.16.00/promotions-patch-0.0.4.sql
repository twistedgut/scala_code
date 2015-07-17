-- this is intended to provide us with better status management of a promotion
BEGIN WORK;

    CREATE TABLE promotion.status (
        id              SERIAL      primary key,
        name            varchar(50) not null,

        UNIQUE(name)
    );
    ALTER TABLE promotion.status OWNER TO www;

    INSERT INTO promotion.status (id, name) VALUES
    (      0, 'UNKNOWN'),
    (default, 'In Progress'),
    (default, 'Job Queued'),
    (default, 'Job Failed'),
    (default, 'Generating Coupons'),
    (default, 'Generated Coupons'),
    (default, 'Generating Customer Lists'),
    (default, 'Generated Customer Lists'),
    (default, 'Exporting Customers'),
    (default, 'Exported Customers'),
    (default, 'Exporting Coupons'),
    (default, 'Exported Coupons'),
    (default, 'Exporting Products'),
    (default, 'Exported Products'),
    (default, 'Exporting To Lyris'),
    (default, 'Exported To Lyris'),
    (default, 'Exporting To PWS'),
    (default, 'Exported To PWS'),
    (default, 'Completed'),
    (default, 'Exported'),
    (default, 'Disabled')
    ;

    -- the main table
    ALTER TABLE promotion.detail
        ADD COLUMN status_id
            integer NOT NULL
            references promotion.status(id)
            default 0
    ;
    -- the matching audit table
    ALTER TABLE audit.promotion_detail
        ADD COLUMN status_id integer
    ;

    -- the main table
    ALTER TABLE promotion.detail
        ADD COLUMN been_exported
            boolean NOT NULL
            default false
    ;
    -- the matching audit table
    ALTER TABLE audit.promotion_detail
        ADD COLUMN been_exported boolean
    ;

    -- the main table
    ALTER TABLE promotion.detail
        ADD COLUMN exported_to_lyris
            boolean NOT NULL
            default false
    ;
    -- the matching audit table
    ALTER TABLE audit.promotion_detail
        ADD COLUMN exported_to_lyris boolean
    ;

    -- anything that currently 'enabled' or 'disabled' (i.e. IS NOT NULL) has
    -- been exported under The Previous Way
    UPDATE promotion.detail SET been_exported=true WHERE enabled IS NOT NULL;

    -- add missing options for the coupon type
    INSERT INTO promotion.coupon_target (id, description)
        VALUES (0, 'No Coupon Required');
    INSERT INTO promotion.coupon_target (id, description)
        VALUES (3, 'Friends and Family');

    -- drop an undesirable FK
    ALTER TABLE promotion.detail_customer
        DROP CONSTRAINT detail_customer_customer_id_fkey
    ;

    ALTER TABLE promotion.coupon
        DROP CONSTRAINT coupon_customer_id_fkey
    ;
COMMIT;
