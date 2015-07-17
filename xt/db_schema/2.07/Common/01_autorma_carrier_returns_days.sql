BEGIN;

    ALTER TABLE public.shipping_account
        ADD COLUMN return_cutoff_days INTEGER DEFAULT NULL;

    ALTER TABLE public.carrier
        ADD COLUMN tracking_uri TEXT DEFAULT NULL;

COMMIT;
