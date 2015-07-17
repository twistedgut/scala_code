
-- DCOP-481: Gift card sold out
-- Sync the web DB with xtracker

use ice_netaporter_intl;

start transaction;

UPDATE stock_location SET no_in_stock = 571, last_updated_dts = now(), version = 635 WHERE sku = '1900004-999';

commit;
