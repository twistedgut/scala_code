-- DCOP-159: Fix process group which is stuck in Bag & Tag

BEGIN;

UPDATE stock_process SET status_id = (
    SELECT id FROM stock_process_status WHERE status = 'Putaway'
)
WHERE group_id = 2299149
AND delivery_item_id = 2890349;

COMMIT;
