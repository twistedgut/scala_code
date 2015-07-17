BEGIN;

    ALTER TABLE public.shipment_item
        ADD COLUMN returnable boolean default true;

COMMIT;
