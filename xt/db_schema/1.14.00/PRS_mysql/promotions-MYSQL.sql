START TRANSACTION;

DROP TABLE IF EXISTS target_city CASCADE;
DROP TABLE IF EXISTS coupon_target CASCADE;
DROP TABLE IF EXISTS coupon_restriction_group CASCADE;
DROP TABLE IF EXISTS coupon_restriction CASCADE;
DROP TABLE IF EXISTS price_group CASCADE;
DROP TABLE IF EXISTS detail CASCADE;
DROP TABLE IF EXISTS website CASCADE;
DROP TABLE IF EXISTS detail_websites CASCADE;
DROP TABLE IF EXISTS detail_seasons CASCADE;
DROP TABLE IF EXISTS detail_designers CASCADE;
DROP TABLE IF EXISTS detail_producttypes CASCADE;
DROP TABLE IF EXISTS shipping_option CASCADE;
DROP TABLE IF EXISTS detail_shippingoptions CASCADE;
DROP TABLE IF EXISTS coupon CASCADE;

    -- a table to provide nice display names mapped to timezone names
    -- (e.g. 'America/New_York')
    CREATE TABLE target_city (
        id              integer      primary key,
        name            varchar(50) not null,
        timezone        varchar(50) not null    default 'UTC',
        display_order   integer     not null    default 9999,

        UNIQUE(name)
    ) Type=InnoDB CHARACTER SET='UTF8';

    -- it makes sense to be able to painlessly search by name
    CREATE UNIQUE INDEX idx_promotion_target_city_name
    ON target_city( name )
    ;

    -- some entries to get things moving, first few should appear at the top
    -- INSERT INTO target_city (name, timezone, display_order) VALUES ('London, UK [INTL]',                 'Europe/London',         1);
    -- INSERT INTO target_city (name, timezone, display_order) VALUES ('New York, USA [East Coast] [AM]',   'America/New_York',      2);
    -- INSERT INTO target_city (name, timezone, display_order) VALUES ('Los Angeles, USA [West Coast]',     'America/Los_Angeles',   3);
    -- the rest should be sorted by name (i.e. use default display_order (of 9999)
    -- INSERT INTO target_city (name, timezone) VALUES ('Paris, France [Europe]',            'Europe/Paris');
    -- INSERT INTO target_city (name, timezone) VALUES ('Berlin, Germany',                   'Europe/Berlin');
    -- INSERT INTO target_city (name, timezone) VALUES ('Copenhagen, Denmark',               'Europe/Copenhagen');
    -- INSERT INTO target_city (name, timezone) VALUES ('Stockholm, Sweden',                 'Europe/Stockholm');
    -- INSERT INTO target_city (name, timezone) VALUES ('Oslo, Norway',                      'Europe/Oslo');
    -- Delhi's zone is deduced from: http://bugs.php.net/bug.php?id=22418
    -- INSERT INTO target_city (name, timezone) VALUES ('Delhi, India',                      'Asia/Katmandu');

    -- who's the coupon targetted at?
    CREATE TABLE coupon_target (
        id              integer      primary key,
        description     varchar(50),

        UNIQUE(description)
    ) Type=InnoDB CHARACTER SET='UTF8';
    -- some default values
    -- INSERT INTO coupon_target (description)
    -- VALUES ('Customer Specific');
    -- INSERT INTO coupon_target (description)
    -- VALUES ('Generic');

--    -- now many items is a coupon limited to?
--    CREATE TABLE coupon_item (
--        id              serial      primary key,
--        description     varchar(50),
--
--        UNIQUE(description)
--    );
--    -- some default values
--    -- INSERT INTO coupon_item (description)
--    VALUES ('limited to 1 item');
--    -- INSERT INTO coupon_item (description)
--    VALUES ('limited to 2 items');
--    -- INSERT INTO coupon_item (description)
--    VALUES ('limited to 3 items');
--    -- INSERT INTO coupon_item (description)
--    VALUES ('limited to 4 items');
--    -- INSERT INTO coupon_item (description)
--    VALUES ('limited to 5 items');
--    -- INSERT INTO coupon_item (description)
--    VALUES ('unlimited items');

-- alter table detail drop column coupon_item_id;
-- drop table coupon_item;


    CREATE TABLE coupon_restriction_group (
        id              integer      primary key,
        idx             integer     not null default 9999,
        name            varchar(50) not null,

        UNIQUE(name)
    ) Type=InnoDB CHARACTER SET='UTF8';

    -- INSERT INTO coupon_restriction_group (name, idx)
    -- VALUES ('Item Limit', 10);
    -- INSERT INTO coupon_restriction_group (name, idx)
    -- VALUES ('Order Limit', 20);

    -- now many items is a coupon limited to?
    CREATE TABLE coupon_restriction (
        id              integer      primary key,
        idx             integer     not null default 9999,
        description     varchar(50),
        group_id        integer     not null
                        references coupon_restriction_group(id),

        usage_limit     integer     default null,

        UNIQUE(description)
    ) Type=InnoDB CHARACTER SET='UTF8';
    -- some default values
    select id from coupon_restriction_group where name='Item Limit' into @grpsql;

    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ( 'limited to 1 item', @grpsql, 10, 1);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 2 items', @grpsql, 20, 2);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 3 items', @grpsql, 30, 3);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 4 items', @grpsql, 40, 4);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 5 items', @grpsql, 50, 5);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('unlimited items', @grpsql, 60, null);

    select id from coupon_restriction_group where name='Order Limit' into @grpsql;
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 1 order', @grpsql, 70, 1);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 2 orders', @grpsql, 80, 2);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 3 orders', @grpsql, 90, 3);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 4 orders', @grpsql, 100, 4);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('limited to 5 orders', @grpsql, 110, 5);
    -- INSERT INTO coupon_restriction (description, group_id, idx, usage_limit)
    -- VALUES ('unlimited orders', @grpsql, 120, null);

    CREATE TABLE price_group (
        id              integer      primary key,
        description     varchar(50),

        UNIQUE(description)
    ) Type=InnoDB CHARACTER SET='UTF8';
    -- INSERT INTO price_group (description)
    -- VALUES ('All (Full Price & Markdown)');
    -- INSERT INTO price_group (description)
    -- VALUES ('Full Price');
    -- INSERT INTO price_group (description)
    -- VALUES ('Markdown');

    -- promotions details - information about the discounts and triggers
    CREATE TABLE detail (
        id              integer      primary key,

        -- originally in summary
        visible_id      varchar(20) not null,

        title           varchar(50) not null,

        start_date      timestamp not null,
        end_date        timestamp null,

        target_city_id  integer     not null
                        references target_city(id),
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

        coupon_prefix           varchar(8),
        coupon_target_id        integer
                references coupon_target(id),
        coupon_restriction_id   integer
                references coupon_restriction(id),

        email_required          boolean not null default False,

        price_group_id          integer
                references price_group(id),

        basket_trigger_pounds   integer,
        basket_trigger_euros    integer,
        basket_trigger_dollars  integer,

        UNIQUE(visible_id),
        UNIQUE(title)
    ) Type=InnoDB CHARACTER SET='UTF8';

    -- make sure we can easily search by visible_id
    CREATE UNIQUE INDEX idx_promotion_detail_visible_id
    ON detail( visible_id )
    ;
    -- make sure we can easily search by visible_id
    CREATE UNIQUE INDEX idx_promotion_title
    ON detail( title )
    ;






    -- list of available web sites
    CREATE TABLE website (
        id              integer      primary key,
        name            varchar(50) not null,

        UNIQUE (name)
    ) Type=InnoDB CHARACTER SET='UTF8';
    -- add websites to the table
    -- INSERT INTO website (name) VALUES ('Intl');
    -- INSERT INTO website (name) VALUES ('AM');

    -- many-to-many join for detail<-->website
    CREATE TABLE detail_websites (
        id              integer      primary key,
        detail_id       integer     not null
                        references  detail(id),
        website_id      integer     not null
                        references  website(id),

        UNIQUE (detail_id, website_id)
    ) Type=InnoDB CHARACTER SET='UTF8';


-- STORED PROCEDURE OMITTED. PERHAPS ADD AGAIN LATER IF NEEDED.
-- create_promotion_trigger

    -- many-to-many join for detail<-->seasons
    CREATE TABLE detail_seasons (
        id              integer      primary key,
        detail_id       integer     not null
                        references  detail(id),
        season_id       integer     not null
                        references  public.season(id),

        UNIQUE (detail_id, season_id)
    ) Type=InnoDB CHARACTER SET='UTF8';

    -- many-to-many join for detail<-->designers
    CREATE TABLE detail_designers (
        id              integer      primary key,
        detail_id       integer     not null
                        references  detail(id),
        designer_id     integer     not null
                        references  public.designer(id),

        UNIQUE (detail_id, designer_id)
    ) Type=InnoDB CHARACTER SET='UTF8';

    -- many-to-many join for detail<-->producttypes
    CREATE TABLE detail_producttypes (
        id              integer      primary key,
        detail_id       integer     not null
                        references  detail(id),
        producttype_id  integer     not null
                        references  public.product_type(id),

        UNIQUE (detail_id, producttype_id)
    ) Type=InnoDB CHARACTER SET='UTF8';


    -- free shipping options
    CREATE TABLE shipping_option (
        id              integer          primary key,
        name            varchar(100)    not null,

        UNIQUE(name)
    ) Type=InnoDB CHARACTER SET='UTF8';
    -- INSERT INTO shipping_option (name) VALUES ('London Premier');
    -- INSERT INTO shipping_option (name) VALUES ('New York Same Day');
    -- INSERT INTO shipping_option (name) VALUES ('Next Business Day');
    -- INSERT INTO shipping_option (name) VALUES ('Ground');

    -- shipping-option <--> detail
    CREATE TABLE detail_shippingoptions (
        id                  integer      primary key,
        detail_id           integer     not null
                            references  detail(id),
        shippingoption_id   integer     not null
                            references  shipping_option(id),

        UNIQUE (detail_id, shippingoption_id)
    ) Type=InnoDB CHARACTER SET='UTF8';


    --
    -- larks, a coupon table!
    --
    CREATE TABLE coupon (
        id                  integer      primary key,
        
        prefix              varchar(8)  not null,
        suffix              varchar(8)  not null,
        code                varchar(17) not null,

        restrict_by_email   boolean     not null    default False,
        email               text,
        -- optional, but potentially pretty useful to have if we know it
        customer_id         integer     references public.customer(id),

        -- if we are limiting the number of uses we need to know:
        -- (1) how many times (2) what type (3) how many times it's been used
        -- already
        usage_limit         integer     default null,
        usage_type_id       integer     references coupon_restriction_group(id),

        -- once a coupon has been used this is a fast way to invalidate it,
        -- making future checks quicker/easier
        valid               boolean     not null    default False,

        UNIQUE(code),
        UNIQUE(prefix,suffix)
    ) Type=InnoDB CHARACTER SET='UTF8';

-- STORED PROCEDURE OMITTED. PERHAPS ADD AGAIN LATER IF NEEDED.
-- create_coupon_code

COMMIT;
