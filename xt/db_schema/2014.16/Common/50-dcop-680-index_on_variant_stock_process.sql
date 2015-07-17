
--
-- DCOP-676 -- add indexes to improve performance of
-- get_stock_process_items
--

BEGIN;

CREATE INDEX ON variant       (designer_size_id);
CREATE INDEX ON stock_process (delivery_item_id);

COMMIT;

