BEGIN;

CREATE TABLE stock_consistency (
    id serial primary key,
    variant_id integer references variant(id) NOT NULL,
    channel_id integer references channel(id) NOT NULL,
    web_quantity integer NOT NULL,
    xt_quantity integer NOT NULL,
    reported integer NOT NULL,
    adjusted boolean NOT NULL DEFAULT false,
    UNIQUE(variant_id, channel_id)
);

GRANT ALL ON stock_consistency TO www;
GRANT ALL ON stock_consistency_id_seq TO www;


CREATE TABLE reservation_consistency (
    id serial primary key,
    variant_id integer references variant(id) NOT NULL,
    channel_id integer references channel(id) NOT NULL,
    customer_number varchar(100) NOT NULL,
    web_quantity integer NOT NULL,
    xt_quantity integer NOT NULL,
    reported integer NOT NULL,
    adjusted boolean NOT NULL DEFAULT false
);

GRANT ALL ON reservation_consistency TO www;
GRANT ALL ON reservation_consistency_id_seq TO www;

COMMIT;
