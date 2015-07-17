BEGIN;

    CREATE SCHEMA promotion AUTHORIZATION www;

    -- a table to provide nice display names mapped to timezone names
    -- (e.g. 'America/New_York')
    CREATE TABLE promotion.target_city (
        id              serial      primary key,
        name            varchar(50) not null,
        timezone        varchar(50) not null    default 'UTC',
        display_order   integer     not null    default 9999,

        UNIQUE(name)
    );

    -- it makes sense to be able to painlessly search by name
    CREATE UNIQUE INDEX idx_promotion_target_city_name
    ON promotion.target_city( name )
    ;

    -- some entries to get things moving, first few should appear at the top
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 1,    'GMT (London)',                             'Europe/London',            1);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 2,    'GMT-5 (New York)',                         'America/New_York',         2);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 3,    'GMT-8 (Los Angeles)',                      'America/Los_Angeles',      3);
    -- everything else
    -- GMT+X
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 4,    'GMT+1 (Paris, Rome, Berlin)',              'Europe/Paris',         105);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 5,    'GMT+2 (Athens, Helsinki, Jerusalem)',      'Europe/Athens',        110);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 6,    'GMT+3 (Kuwait, Moscow, Riyadh)',           'Asia/Kuwait',          115);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 7,    'GMT+4 (Abu Dhabi, Tblisi, Kabul)',         'Asia/Tbilisi',         120);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 8,    'GMT+5 (Tashkent)',                         'Asia/Tashkent',        125);
    -- this one needs double checking;
    -- Delhi's zone was deduced from: http://bugs.php.net/bug.php?id=22418
    -- http://www.davidsemporium.co.uk/worldclock2.html makes us think it's
    -- incorrect
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES ( 9,    'GMT+5:30 (Delhi)',                         'Asia/Katmandu',        130);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (10,    'GMT+6 (Colombo)',                          'Asia/Colombo',         135);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (11,    'GMT+7 (Bangkok, Jakarta)',                 'Asia/Bangkok',         140);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (12,    'GMT+8 (Singapore, Hong Kong, Beijing)',    'Asia/Singapore',       145);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (13,    'GMT+9 (Tokyo)',                            'Asia/Tokyo',           150);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (14,    'GMT+10 (Sydney)',                          'Australia/Sydney',     155);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (15,    'GMT+11 (New Caledonia, Magadan)',          'Asia/Magadan',         160);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (16,    'GMT+12 (Wellington, Fiji)',                'Pacific/Fiji',         165);
    -- GMT-X
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (17,    'GMT-1 (Azores, Cape Verde Islands)',       'Atlantic/Azores',      205);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (18,    'GMT-2 (Mid-Atlantic)',                     '-0200',                210);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (19,    'GMT-3 (Brasilia, Buenos Aires)', 'Argentina/Buenos_Aires',         215);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (20,    'GMT-4 (Caracas, La Paz, Santiago)',        'America/Santiago',     220);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (21,    'GMT-6 (Mexico City, Chicago)',             'America/Chicago',      225);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (22,    'GMT-7 (Denver)',                           'America/Denver',       230);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (23,    'GMT-9 (Juneau, Alaska)',                   'America/Juneau',       235);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (24,    'GMT-10 (Honolulu, Hawaii)',                'Pacific/Honolulu',     240);
    INSERT INTO promotion.target_city (id, name, timezone, display_order) VALUES (25,    'GMT-11 (Midway Island)',                   'Pacific/Midway',       245);

    -- who's the coupon targetted at?
    CREATE TABLE promotion.coupon_target (
        id              serial      primary key,
        description     varchar(50),

        UNIQUE(description)
    );
    -- some default values
    INSERT INTO promotion.coupon_target (id, description) VALUES (1, 'Customer Specific');
    INSERT INTO promotion.coupon_target (id, description) VALUES (2, 'Generic');

    CREATE TABLE promotion.coupon_restriction_group (
        id              serial      primary key,
        idx             integer     not null default(9999),
        name            varchar(50) not null,

        UNIQUE(name)
    );
    INSERT INTO promotion.coupon_restriction_group (id, name, idx) VALUES (1, 'Item Limit', 10);
    INSERT INTO promotion.coupon_restriction_group (id, name, idx) VALUES (2, 'Order Limit', 20);

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



    -- now many items is a coupon limited to?
    CREATE TABLE promotion.coupon_restriction (
        id              serial      primary key,
        idx             integer     not null default(9999),
        description     varchar(50),
        group_id        integer     not null
                        references promotion.coupon_restriction_group(id),

        usage_limit     integer     default(null),

        UNIQUE(description)
    );
    -- some default values
    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Item Limit\')'
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (1, 'limited to 1 item', :grpsql, 10, 1);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (2, 'limited to 2 items', :grpsql, 20, 2);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (3, 'limited to 3 items', :grpsql, 30, 3);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (4, 'limited to 4 items', :grpsql, 40, 4);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (5, 'limited to 5 items', :grpsql, 50, 5);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (6, 'unlimited items', :grpsql, 60, null);

    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Order Limit\')'
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (7, 'limited to 1 order', :grpsql, 70, 1);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (8, 'limited to 2 orders', :grpsql, 80, 2);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (9, 'limited to 3 orders', :grpsql, 90, 3);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (10, 'limited to 4 orders', :grpsql, 100, 4);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (11, 'limited to 5 orders', :grpsql, 110, 5);
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES (12, 'unlimited orders', :grpsql, 120, null);

    CREATE TABLE promotion.price_group (
        id              serial      primary key,
        description     varchar(50),

        UNIQUE(description)
    );
    INSERT INTO promotion.price_group (id, description)
    VALUES (1, 'All (Full Price & Markdown)');
    INSERT INTO promotion.price_group (id, description)
    VALUES (2, 'Full Price');
    INSERT INTO promotion.price_group (id, description)
    VALUES (3, 'Markdown');

    -- promotions details - information about the discounts and triggers
    CREATE TABLE promotion.detail (
        id                  serial      primary key,
        created             timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
        created_by          integer references operator(id),
        last_modified       timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
        last_modified_by    integer references operator(id),

        -- from promotion.summary
        visible_id      varchar(20) not null,

        title           varchar(50) not null,

        start_date      timestamp with time zone not null,
        end_date        timestamp with time zone,

        target_city_id  integer     not null
                        references promotion.target_city(id),
        -- end

        -- null: we haven't done anything with it
        -- true: a manager enabled it
        -- false: it was enabled, now it isn't
        enabled         boolean     null default null,


        offer_type              varchar(50),

        discount_percentage     integer,
        discount_pounds         integer,
        discount_euros          integer,
        discount_dollars        integer,

        -- TODO: free shipping
        -- TODO: applicable website(s)

        coupon_prefix           varchar(8),
        coupon_target_id        integer
                references promotion.coupon_target(id),
        coupon_restriction_id   integer
                references promotion.coupon_restriction(id),
        coupon_generation_id    integer default NULL
                references promotion.coupon_generation(id),

        price_group_id          integer
                references promotion.price_group(id),

        basket_trigger_pounds   integer,
        basket_trigger_euros    integer,
        basket_trigger_dollars  integer,

        order_line_heading      character varying(30),
        order_line_text         character varying(75)
    );


    -- make sure we can easily search by visible_id
    CREATE UNIQUE INDEX idx_promotion_detail_visible_id
    ON promotion.detail( visible_id )
    ;
    -- make sure we can easily search by visible_id
    CREATE UNIQUE INDEX idx_promotion_title
    ON promotion.detail( title )
    ;


    -- auditing table
    CREATE TABLE audit.promotion_detail (
        action                  VARCHAR(6),

        id                  integer,
        created             timestamp with time zone,
        created_by          integer references operator(id),
        last_modified       timestamp with time zone,
        last_modified_by    integer references operator(id),

        -- from promotion.summary
        visible_id      varchar(20) not null,

        title           varchar(50) not null,

        start_date      timestamp with time zone not null,
        end_date        timestamp with time zone,

        target_city_id  integer     not null
                        references promotion.target_city(id),
        -- end

        -- null: we haven't done anything with it
        -- true: a manager enabled it
        -- false: it was enabled, now it isn't
        enabled         boolean     null default null,


        offer_type              varchar(50),

        discount_percentage     integer,
        discount_pounds         integer,
        discount_euros          integer,
        discount_dollars        integer,

        -- TODO: free shipping
        -- TODO: applicable website(s)

        coupon_prefix           varchar(8),
        coupon_target_id        integer
                references promotion.coupon_target(id),
        coupon_restriction_id   integer
                references promotion.coupon_restriction(id),
        coupon_generation_id    integer default NULL
                references promotion.coupon_generation(id),

        price_group_id          integer
                references promotion.price_group(id),

        basket_trigger_pounds   integer,
        basket_trigger_euros    integer,
        basket_trigger_dollars  integer,

        order_line_heading      character varying(30),
        order_line_text         character varying(75)
    );
    ALTER TABLE audit.promotion_detail OWNER TO www;



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

    CREATE TRIGGER promotion_detail_audit_tgr AFTER INSERT OR UPDATE OR DELETE
    ON promotion.detail
        FOR EACH ROW EXECUTE PROCEDURE audit.promotion_detail_trigger();



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



    -- list of available web sites
    CREATE TABLE promotion.website (
        id              serial      primary key,
        name            varchar(50) not null,

        UNIQUE (name)
    );
    -- add websites to the table
    INSERT INTO promotion.website (id, name) VALUES (1, 'Intl');
    INSERT INTO promotion.website (id, name) VALUES (2, 'AM');

    -- many-to-many join for detail<-->website
    CREATE TABLE promotion.detail_websites (
        id              serial      primary key,
        detail_id       integer     not null
                        references  promotion.detail(id),
        website_id      integer     not null
                        references  promotion.website(id),

        UNIQUE (detail_id, website_id)
    );


    -- a BEFORE INSERT function and trigger to generate the (visible)
    -- Promotion ID (based on the PK id value
    CREATE OR REPLACE FUNCTION create_promotion_trigger() RETURNS
        trigger AS $$
    BEGIN

        IF (length(NEW.id) > 6) THEN
            -- even though there are claims that there'll never be a million
            -- promotions, let's make sure things don't grind to a halt
            -- if/when it happens
            RAISE NOTICE '...and they said there would never be more than a million promotions!';
            NEW.visible_id := 'PRS-' || NEW.id;
        ELSE
            NEW.visible_id := 'PRS-' || lpad(NEW.id, 6, '0');
        END IF;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER promotion_detail_tgr BEFORE INSERT
    ON promotion.detail
        FOR EACH ROW EXECUTE PROCEDURE create_promotion_trigger();



    -- many-to-many join for detail<-->seasons
    CREATE TABLE promotion.detail_seasons (
        id              serial      primary key,
        detail_id      integer     not null
                        references  promotion.detail(id),
        season_id       integer     not null
                        references  public.season(id),

        UNIQUE (detail_id, season_id)
    );

    -- many-to-many join for detail<-->designers
    CREATE TABLE promotion.detail_designers (
        id              serial      primary key,
        detail_id      integer     not null
                        references  promotion.detail(id),
        designer_id     integer     not null
                        references  public.designer(id),

        UNIQUE (detail_id, designer_id)
    );

    -- many-to-many join for detail<-->producttypes
    CREATE TABLE promotion.detail_producttypes (
        id              serial      primary key,
        detail_id      integer     not null
                        references  promotion.detail(id),
        producttype_id  integer     not null
                        references  public.product_type(id),

        UNIQUE (detail_id, producttype_id)
    );


    -- free shipping options
    CREATE TABLE promotion.shipping_option (
        id              serial          primary key,
        name            varchar(100)    not null,

        UNIQUE(name)
    );

--    INSERT INTO promotion.shipping_option (id, name) VALUES (1, 'London Premier');
--    INSERT INTO promotion.shipping_option (id, name) VALUES (2, 'New York Same Day');
--    INSERT INTO promotion.shipping_option (id, name) VALUES (3, 'Next Business Day');
--    INSERT INTO promotion.shipping_option (id, name) VALUES (4, 'Ground');

    INSERT INTO promotion.shipping_option (id, name) VALUES (1, 'London Premier');
    INSERT INTO promotion.shipping_option (id, name) VALUES (2, 'UK Standard');
    INSERT INTO promotion.shipping_option (id, name) VALUES (3, 'US Next Business Day');
    INSERT INTO promotion.shipping_option (id, name) VALUES (4, 'US Ground');
    INSERT INTO promotion.shipping_option (id, name) VALUES (5, 'New York Premier');

    -- shipping-option <--> detail
    CREATE TABLE promotion.detail_shippingoptions (
        id                  serial      primary key,
        detail_id           integer     not null
                            references  promotion.detail(id),
        shippingoption_id   integer     not null
                            references  promotion.shipping_option(id),

        UNIQUE (detail_id, shippingoption_id)
    );



    --
    -- larks, a coupon table!
    --
    CREATE TABLE promotion.coupon (
        id                  serial      primary key,
        
        prefix              varchar(8)  not null,
        suffix              varchar(8)  not null,
        code                varchar(17) not null,

        -- what promotion does the coupon belong to?
         promotion_detail_id    integer NOT NULL
                                    references promotion.detail(id),

        restrict_by_email   boolean     not null    default False,
        email               text,
        -- optional, but potentially pretty useful to have if we know it
        customer_id         integer     references public.customer(id),

        -- coupon usage count
        usage_count         integer,

        -- if we are limiting the number of uses we need to know:
        -- (1) how many times (2) what type (3) how many times it's been used
        -- already
        usage_limit         integer     default null,
        usage_type_id       integer     references promotion.coupon_restriction_group(id),

        -- once a coupon has been used this is a fast way to invalidate it,
        -- making future checks quicker/easier
        valid               boolean     not null    default False,

        UNIQUE(code),
        UNIQUE(prefix,suffix)
    );
    -- a BEFORE INSERT function and trigger to generate the full coupon code
    CREATE OR REPLACE FUNCTION create_coupon_code() RETURNS
        trigger AS $$
    BEGIN
        NEW.code := NEW.prefix || '-' || NEW.suffix;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER promotion_coupon_tgr BEFORE INSERT
    ON promotion.coupon
        FOR EACH ROW EXECUTE PROCEDURE create_coupon_code();






    -- make sure that 'www' owns all the tables
    ALTER TABLE promotion.coupon_restriction OWNER TO www;
    ALTER TABLE promotion.coupon_restriction_group OWNER TO www;
    ALTER TABLE promotion.coupon_target OWNER TO www;
    ALTER TABLE promotion.detail OWNER TO www;
    ALTER TABLE promotion.detail_websites OWNER TO www;
    ALTER TABLE promotion.price_group OWNER TO www;
    ALTER TABLE promotion.detail_designers OWNER TO www;
    ALTER TABLE promotion.detail_producttypes OWNER TO www;
    ALTER TABLE promotion.detail_seasons OWNER TO www;
    ALTER TABLE promotion.target_city OWNER TO www;
    ALTER TABLE promotion.website OWNER TO www;
    ALTER TABLE promotion.shipping_option OWNER TO www;
    ALTER TABLE promotion.detail_shippingoptions OWNER TO WWW;
    ALTER TABLE promotion.coupon OWNER TO WWW;

COMMIT;
