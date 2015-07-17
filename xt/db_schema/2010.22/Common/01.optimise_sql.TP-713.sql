-- http://jira.nap/browse/TP-713
--
-- Before:
--   HashAggregate (cost=101511.44..101608.80 rows=2434 width=134) (actual time=1392.192..1400.041 rows=2519 loops=1)
--   Total runtime: 1401.028 ms
--
--   HashAggregate  (cost=48674.42..48753.62 rows=1980 width=132) (actual time=543.367..551.162 rows=2519 loops=1)
--   Total runtime: 551.904 ms

BEGIN;
    CREATE INDEX return_item_status_log_return_item_status_id ON public.return_item_status_log(return_item_status_id);
    CREATE INDEX return_item_customer_issue_type_id ON return_item(customer_issue_type_id);
    CREATE INDEX return_item_status_log_return_item_id ON public.return_item_status_log(return_item_id);
COMMIT;
