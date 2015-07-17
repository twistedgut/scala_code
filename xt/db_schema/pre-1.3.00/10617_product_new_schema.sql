BEGIN;

CREATE SCHEMA product;
GRANT ALL ON SCHEMA product TO www;

-- list items that are products
CREATE TABLE product.list_item (
    id              SERIAL PRIMARY KEY,
    listitem_id     INTEGER NOT NULL REFERENCES list.item(id),
    product_id      INTEGER NOT NULL REFERENCES public.product(id),
    priority        BOOLEAN DEFAULT FALSE NOT NULL,
    late_addition   BOOLEAN DEFAULT FALSE NOT NULL
);
GRANT ALL ON product.list_item TO www;
GRANT ALL ON product.list_item_id_seq TO www;


COMMIT;
