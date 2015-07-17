-- RES-W130

BEGIN;

UPDATE stock_process SET quantity = 1 WHERE group_id = 4204156;

COMMIT;
