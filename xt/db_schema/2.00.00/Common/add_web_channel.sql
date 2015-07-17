

BEGIN;

ALTER TABLE channel ADD COLUMN web_name varchar(50);

UPDATE channel SET web_name = 'NAP-INTL' WHERE id = 1;
UPDATE channel SET web_name = 'NAP-AM' WHERE id = 2;
UPDATE channel SET web_name = 'OUTNET-INTL' WHERE id = 3;
UPDATE channel SET web_name = 'OUTNET-AM' WHERE id = 4;

COMMIT;
