-- Add Gift Voucher total to 'renumeration' table

BEGIN WORK;

ALTER TABLE public.renumeration
    ADD COLUMN gift_voucher numeric(10,3) default 0
;

COMMIT WORK;
