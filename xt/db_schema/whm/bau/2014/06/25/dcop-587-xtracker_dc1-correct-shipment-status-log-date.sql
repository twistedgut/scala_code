-- DC1 fix incorrect date on shipment status log

BEGIN;

UPDATE shipment_status_log 
SET date = date + interval '2000 years' 
WHERE id = '10788458';

COMMIT;
