BEGIN;

update stock_count set counted_quantity = 0 where id in (385937, 385939) and counted_quantity = 233383;

COMMIT;
