-- Add extra table to track QC failure of shipment paperwork at packing

BEGIN;


    CREATE TABLE shipment_extra_item (
        id SERIAL PRIMARY KEY ,
        shipment_id integer NOT NULL references shipment(id),
        item_type character varying(255) NOT NULL,
        qc_failure_reason text NOT NULL
    );

    ALTER TABLE public.shipment_extra_item OWNER TO www;

    -- we'll always be looking this up by shipment_id
    CREATE INDEX shipment_extra_item_shipment_id ON shipment_extra_item USING btree (shipment_id);


COMMIT;
