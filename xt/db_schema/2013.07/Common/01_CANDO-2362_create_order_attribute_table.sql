--
-- CANDO-2362 Create order_attribute table
--

BEGIN WORK;

CREATE TABLE order_attribute (
    id                  SERIAL NOT NULL PRIMARY KEY,
    orders_id           INTEGER NOT NULL UNIQUE REFERENCES public.orders(id),
    source_app_name     CHARACTER VARYING(255),
    source_app_version  CHARACTER VARYING(255)
);

ALTER TABLE order_attribute OWNER TO postgres;
GRANT ALL ON TABLE order_attribute TO www;
GRANT ALL ON SEQUENCE order_attribute_id_seq TO www;

COMMIT WORK;
