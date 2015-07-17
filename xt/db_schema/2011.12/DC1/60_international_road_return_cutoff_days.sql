BEGIN;

-- FLEX-186
-- Set return_cutoff_days for International Road to 23 days

UPDATE shipping_account SET return_cutoff_days = 23 WHERE name = 'International Road';

COMMIT;
