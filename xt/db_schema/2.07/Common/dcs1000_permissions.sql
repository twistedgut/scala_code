BEGIN;
    ALTER TABLE public.payment_settlement_discount OWNER TO www;
    ALTER TABLE public.payment_deposit OWNER TO www;

    ALTER TABLE public.payment_deposit
        ALTER COLUMN deposit_percentage TYPE double precision
    ;
COMMIT;
