-- http://jira.nap/browse/TP-714
--
-- Before:
--   HashAggregate (cost=12618.32..12618.47 rows=6 width=73) (actual time=338.452..339.182 rows=301 loops=1)
--   Total runtime: 339.803 ms
--
-- After:
--    HashAggregate  (cost=11794.00..11794.13 rows=5 width=73) (actual time=299.487..300.205 rows=301 loops=1)
--     Total runtime: 300.475 ms

BEGIN;
    CREATE INDEX link_delivery__stock_order_stock_order_id ON public.link_delivery__stock_order(stock_order_id);
    CREATE INDEX stock_process_quantity ON stock_process(quantity);
COMMIT;
