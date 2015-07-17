BEGIN;

-- add column when_confirmed. This is when the PO was confirmed and will be used by MIS
ALTER TABLE public.purchase_order ADD COLUMN when_confirmed TIMESTAMP WITH TIME ZONE DEFAULT NULL;

COMMENT ON COLUMN public.purchase_order.when_confirmed IS 'Time when the PO was confirmed. Null if not confirmed yet. Will be used by MIS to pull confirmed PO into financial audit system.';

COMMIT;
