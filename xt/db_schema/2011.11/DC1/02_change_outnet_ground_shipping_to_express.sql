BEGIN;

-- FLEX-39
-- Migrate the current DHL ground shipping to the DHL international
-- network so that all legacy infrastructure can be decommisioned and
-- traffic is moved to one single international platform

UPDATE shipping_account
  SET
     account_number     = '184097744'
    ,name               = 'International Road' -- From old 'Europlus International'
    ,carrier_id         = 1                    -- DHL Express, from old 'DHL Ground'
    ,return_cutoff_days = 16                   -- Same quality of service as current
  WHERE id = 6
;

COMMIT;
