BEGIN;

    CREATE TABLE product.external_image_url (
        id SERIAL PRIMARY KEY NOT NULL,
        product_id integer NOT NULL REFERENCES public.product(id) DEFERRABLE,
        url text NOT NULL
    );

    COMMENT ON TABLE product.external_image_url IS 'External images associated with this product channel will be stored here. See PM-1473 for more detail';

    ALTER TABLE product.external_image_url OWNER TO www;

COMMIT;
