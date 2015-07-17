BEGIN;

ALTER TABLE product_channel DROP CONSTRAINT product_channel_transfer_status_id_fkey;

DROP TABLE channel_transfer_status;

CREATE TABLE product_channel_transfer_status (
    id serial primary key,
    status varchar(100) NOT NULL UNIQUE
);

GRANT ALL ON product_channel_transfer_status TO www;
GRANT ALL ON product_channel_transfer_status_id_seq TO www;

INSERT INTO product_channel_transfer_status VALUES (1, 'None');
INSERT INTO product_channel_transfer_status VALUES (2, 'Requested');
INSERT INTO product_channel_transfer_status VALUES (3, 'In Progress');
INSERT INTO product_channel_transfer_status VALUES (4, 'Transferred');

ALTER TABLE product_channel ADD CONSTRAINT product_channel_transfer_status_id_fkey FOREIGN KEY (transfer_status_id) REFERENCES product_channel_transfer_status(id) MATCH FULL;


CREATE TABLE channel_transfer_status (
    id serial primary key,
    status varchar(100) NOT NULL UNIQUE
);

GRANT ALL ON channel_transfer_status TO www;
GRANT ALL ON channel_transfer_status_id_seq TO www;

INSERT INTO channel_transfer_status VALUES (1, 'Requested');
INSERT INTO channel_transfer_status VALUES (2, 'Selected');
INSERT INTO channel_transfer_status VALUES (3, 'Incomplete Pick');
INSERT INTO channel_transfer_status VALUES (4, 'Picked');
INSERT INTO channel_transfer_status VALUES (5, 'Complete');

CREATE TABLE channel_transfer (
    id serial primary key,
    product_id integer references product(id) NOT NULL,
    from_channel_id integer references channel(id) NOT NULL,
    to_channel_id integer references channel(id) NOT NULL,
    status_id integer references channel_transfer_status(id) NOT NULL
);

GRANT ALL ON channel_transfer TO www;
GRANT ALL ON channel_transfer_id_seq TO www;


CREATE TABLE log_channel_transfer (
    id serial primary key,
    channel_transfer_id integer references channel_transfer(id) NOT NULL,
    status_id integer references channel_transfer_status(id) NOT NULL,
    operator_id integer references operator(id) NOT NULL,
    date timestamp NOT NULL
);

GRANT ALL ON log_channel_transfer TO www;
GRANT ALL ON log_channel_transfer_id_seq TO www;


CREATE TABLE channel_transfer_pick (
    id serial primary key,
    channel_transfer_id integer references channel_transfer(id) NOT NULL,
    variant_id integer references variant(id) NOT NULL,
    location_id integer references location(id) NOT NULL,
    expected_quantity integer NOT NULL DEFAULT 0,
    picked_quantity integer NOT NULL DEFAULT 0,
    operator_id integer references operator(id) NOT NULL,
    date timestamp NOT NULL
);

GRANT ALL ON channel_transfer_pick TO www;
GRANT ALL ON channel_transfer_pick_id_seq TO www;

CREATE TABLE channel_transfer_putaway (
    id serial primary key,
    channel_transfer_id integer references channel_transfer(id) NOT NULL,
    variant_id integer references variant(id) NOT NULL,
    location_id integer references location(id) NOT NULL,
    quantity integer NOT NULL DEFAULT 0,
    operator_id integer references operator(id) NOT NULL,
    date timestamp NOT NULL
);

GRANT ALL ON channel_transfer_putaway TO www;
GRANT ALL ON channel_transfer_putaway_id_seq TO www;

insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Stock Control'), 'Channel Transfer', (select max(id) + 1 from authorisation_sub_section where authorisation_section_id = (select id from authorisation_section where section = 'Stock Control') group by authorisation_section_id));

INSERT INTO stock_count_origin VALUES (default, 'Channel Transfer');

COMMIT;