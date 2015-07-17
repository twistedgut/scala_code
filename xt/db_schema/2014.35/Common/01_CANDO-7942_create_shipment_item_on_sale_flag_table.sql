--
-- CANDO-7942: Create shipment_item_on_sale_flag table
--

BEGIN WORK;

CREATE TABLE shipment_item_on_sale_flag (
    id serial not null primary key,
    pws_key character varying(255) not null,
    flag character varying(255) not null,
    on_sale boolean not null default false
);

ALTER TABLE public.shipment_item_on_sale_flag OWNER TO postgres;
GRANT ALL ON TABLE public.shipment_item_on_sale_flag TO www;
GRANT ALL ON SEQUENCE public.shipment_item_on_sale_flag_id_seq TO www;

INSERT INTO shipment_item_on_sale_flag
    ( pws_key, flag, on_sale )
VALUES ( 'YES', 'Yes', true );

INSERT INTO shipment_item_on_sale_flag
    ( pws_key, flag, on_sale )
VALUES ( 'NO', 'No', false );

COMMIT WORK;

