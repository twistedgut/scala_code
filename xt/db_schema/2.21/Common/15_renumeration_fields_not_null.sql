BEGIN;
    UPDATE public.renumeration SET gift_credit = 0 WHERE gift_credit IS NULL;
    UPDATE public.renumeration SET store_credit = 0 WHERE store_credit IS NULL;
    UPDATE public.renumeration SET misc_refund = 0 WHERE misc_refund IS NULL;
    UPDATE public.renumeration SET gift_voucher = 0 WHERE gift_voucher IS NULL;
    ALTER TABLE public.renumeration
        ALTER COLUMN gift_credit SET NOT NULL,
        ALTER COLUMN store_credit SET NOT NULL,
        ALTER COLUMN misc_refund SET NOT NULL,
        ALTER COLUMN gift_voucher SET NOT NULL;
COMMIT;
