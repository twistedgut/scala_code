BEGIN;

-- FLEX-713 - clean up the shipping schema which isn't used

DROP TABLE shipping.zone CASCADE;
DROP TABLE shipping.option_zone CASCADE;
DROP TABLE shipping.option_ups CASCADE;
DROP TABLE shipping.option_nap CASCADE;
DROP TABLE shipping.option_dhl CASCADE;
DROP TABLE shipping.option CASCADE;
DROP TABLE shipping.location CASCADE;
DROP TABLE shipping.charge CASCADE;
DROP TABLE shipping.carrier CASCADE;
DROP TABLE shipping.option_type CASCADE;
DROP TABLE shipping.account CASCADE;

COMMIT;
