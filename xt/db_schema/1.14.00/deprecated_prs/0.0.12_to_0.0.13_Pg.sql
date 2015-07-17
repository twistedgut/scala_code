-- A quick apology: I let myself get all confused and mixed up.
-- I didn't stick with my own way of working, and stupidly made additions to
-- the previous patch file that shouldn't be in it.
--
-- Hopefully I've caught them all, and they're now in this file.

BEGIN WORK;
    -- coupon usage count
    ALTER TABLE promotion.coupon
        ADD COLUMN usage_count integer
    ;
 
    -- coupon generation action
    CREATE TABLE promotion.coupon_generation (
        id                      SERIAL primary key,
        idx                     integer not null default(9999),
        action                  character varying(50),
        description             text not null,

        UNIQUE (action)
    );
    ALTER TABLE promotion.coupon_generation OWNER TO www;
    INSERT INTO promotion.coupon_generation (idx,action,description)
    VALUES
    (10,'coupon_only','Generate Coupon Only');
    INSERT INTO promotion.coupon_generation (idx,action,description)
    VALUES
    (20,'coupon_and_send','Generate Coupon and Send Email');

    ALTER TABLE promotion.detail
        ADD COLUMN coupon_generation_id integer default NULL
                        references promotion.coupon_generation(id)
    ;

    -- we don't use email_required any more
    ALTER TABLE promotion.detail
        DROP COLUMN email_required
    ;
    -- storing individual PIDs
    CREATE TABLE promotion.detail_products (
        id              serial      primary key,
        detail_id       integer     not null
                        references  promotion.detail(id),
        product_id      integer     not null
                        references  public.product(id),

        UNIQUE (detail_id, product_id)
    );
    ALTER TABLE promotion.detail_products OWNER TO www;


    -- the names of customer groupings, e.g. EIP, High Spender
    CREATE TABLE promotion.customer_group (
        id                  SERIAL          primary key,
        name                varchar(50)     not null,

        UNIQUE(name)
    );
    ALTER TABLE promotion.customer_group OWNER TO www;

        -- customer group restrictions
    CREATE TABLE promotion.customergroup_listtype (
        id                  SERIAL         primary key,
        name                varchar(50)    not null,
        UNIQUE(name)
    );
    ALTER TABLE promotion.customergroup_listtype OWNER TO www;
    INSERT INTO promotion.customergroup_listtype (name) VALUES ('include');
    INSERT INTO promotion.customergroup_listtype (name) VALUES ('exclude');

    -- link a promotion to one or more customer groupings
    CREATE TABLE promotion.detail_customergroup (
        id                  SERIAL          primary key,

        -- the promotion
        detail_id           integer         not null
                            references promotion.detail(id),
        -- the grouping
        customergroup_id    integer         not null
                            references promotion.customer_group(id),

        -- whether the entry lives in the include/exclude list
        listtype_id         integer         not null
                            references promotion.customergroup_listtype(id),

        -- we only want each group to appear (a maximum of) once per promotion
        UNIQUE (detail_id, customergroup_id)
    );
    ALTER TABLE promotion.detail_customergroup OWNER TO www;

    -- we want to be able to say if the customer groups are joined with an
    -- AND or an OR
    CREATE TABLE promotion.detail_customergroup_join (
        id                  SERIAL          primary key,
        type                varchar(10)     not null,

        CHECK( (type='AND') OR (type='OR') ),
        
        UNIQUE(type)
    );
    ALTER TABLE promotion.detail_customergroup_join OWNER TO www;
    INSERT INTO promotion.detail_customergroup_join (id,type) VALUES (1,'AND');
    INSERT INTO promotion.detail_customergroup_join (id,type) VALUES (2,'OR');
    -- make the next value in the sequence '3'
    SELECT setval('promotion.detail_customergroup_join_id_seq', 2, true);

    -- we will want to have customers linked to specific promotions
    -- (frozen after the Go Live button clicked)
    -- this is what we'll punt out to the website
    CREATE TABLE promotion.detail_customer (
        id                  SERIAL          primary key,

        -- the promotion
        detail_id           integer         not null
                            references promotion.detail(id),

        -- the customer
        customer_id         integer         not null
                            references public.customer(id),

        -- each customer only once per promotion
        UNIQUE(detail_id, customer_id)
    );
    ALTER TABLE promotion.detail_customer OWNER TO www;

    -- and let's allow customers to live in groups
    CREATE TABLE promotion.customer_customergroup (
        id                  SERIAL          primary key,

        -- the customer
        customer_id         integer         not null
                            references public.customer(id),

        -- the grouping
        customergroup_id    integer         not null
                            references promotion.customer_group(id),

        -- each customer can only belong to each group once
        UNIQUE(customer_id,customergroup_id)
    );
    ALTER TABLE promotion.customer_customergroup OWNER TO www;



    -- this looks identical to promotion.detail_products, but it's the
    -- freezing of the products that are the restrictions for a promotion
    -- at a given time
    CREATE TABLE promotion.detail_product (
        id              serial      primary key,
        detail_id       integer     not null
                        references  promotion.detail(id),
        product_id      integer     not null
                        references  public.product(id),

        UNIQUE (detail_id, product_id)
    );
    ALTER TABLE promotion.detail_product OWNER TO www;



    CREATE OR REPLACE FUNCTION audit.promotion_detail_trigger() RETURNS
        trigger AS $$
    DECLARE
        v_table     TEXT := '''';
    BEGIN

        -- FIXME: factor this out into a mapping from RELID->audit.sumtable
        v_table := 'audit.promotion';

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

