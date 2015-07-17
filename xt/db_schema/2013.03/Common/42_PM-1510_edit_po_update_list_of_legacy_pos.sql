-- PM-1510

-- We want to backfill the purchase_orders_not_editable_in_fulcrum
-- with all the purchase orders found on the purchase order table.

-- We had to insert the "SELECT DISTINCT" statement because the
-- public.purchase_order doesn't has a UNIQUE constraint on the
-- purchase_order_number column, so we had different PO entries
-- with the same PO number

BEGIN;

DELETE FROM public.purchase_orders_not_editable_in_fulcrum;

INSERT INTO public.purchase_orders_not_editable_in_fulcrum (SELECT DISTINCT purchase_order_number FROM public.purchase_order);

COMMIT;
