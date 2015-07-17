BEGIN;
    ALTER TABLE public.purchase_order ADD FOREIGN KEY (currency_id) REFERENCES currency;
    ALTER TABLE voucher.purchase_order ADD FOREIGN KEY (currency_id) REFERENCES currency;
    ALTER TABLE public.super_purchase_order ADD FOREIGN KEY (currency_id) REFERENCES currency;
COMMIT;
