BEGIN;

ALTER TABLE public.shipment
    ADD COLUMN packing_other_info TEXT DEFAULT NULL;


COMMIT;
