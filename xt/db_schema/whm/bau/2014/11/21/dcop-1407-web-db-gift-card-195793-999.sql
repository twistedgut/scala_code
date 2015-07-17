
-- DCOP-1404: Gift card sold out
-- Sync the web DB with xtracker

use mrp_intl;

start transaction;

UPDATE stock_location SET no_in_stock = 526, last_updated_dts = now(), version = version+1 WHERE sku = '195793-999';

commit;
