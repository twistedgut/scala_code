BEGIN;

CREATE TABLE quarantine_process (
    id serial primary key NOT NULL,
    variant_id integer NOT NULL references variant(id),
    channel_id integer NOT NULL references channel(id)
);

GRANT ALL ON quarantine_process TO www;
GRANT ALL ON quarantine_process_id_seq TO www;

CREATE TABLE link_delivery_item__quarantine_process (
    delivery_item_id integer NOT NULL references delivery_item(id),
    quarantine_process_id integer NOT NULL references quarantine_process(id)
);

GRANT ALL ON link_delivery_item__quarantine_process TO www;

COMMIT;