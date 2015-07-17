-- http://jira.nap/browse/TP-712
--
-- Before:
--   Sort  (cost=20801.59..20801.60 rows=2 width=88) (actual time=141.765..141.766 rows=4 loops=1)
--   Total runtime: 141.978 ms
--
-- After:
--   Sort  (cost=4178.53..4178.53 rows=2 width=88) (actual time=12.177..12.177 rows=4 loops=1)
--   Total runtime: 12.390 ms

BEGIN;

    CREATE INDEX stock_process_status_id ON public.stock_process(status_id);
    CREATE INDEX stock_process_complete ON public.stock_process(complete);
    CREATE INDEX link_stock_transfer__shipment_shipment_id ON public.link_stock_transfer__shipment(shipment_id);
    CREATE INDEX stock_process_delivery_item_id ON public.stock_process(delivery_item_id);
    CREATE INDEX link_delivery_item__shipment_item_delivery_item_id ON link_delivery_item__shipment_item(delivery_item_id);

COMMIT;
