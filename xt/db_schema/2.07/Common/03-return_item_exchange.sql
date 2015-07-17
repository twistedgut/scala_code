BEGIN;

    ALTER TABLE public.return_item
        ADD COLUMN exchange_shipment_item_id INTEGER REFERENCES shipment_item (id) DEFERRABLE;

    -- Data for the above column is populates via a script (or will be) since
    -- it is *horrible* to do in SQL

COMMIT;
