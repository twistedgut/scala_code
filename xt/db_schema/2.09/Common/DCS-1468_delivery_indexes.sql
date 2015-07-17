BEGIN;
    -- this one makes *lots* of difference
    CREATE INDEX idx_public_delivery_date ON public.delivery(date);
    -- this is useful but less critical
    CREATE INDEX idx_public_delivery_type ON public.delivery_type(type);
COMMIT;
