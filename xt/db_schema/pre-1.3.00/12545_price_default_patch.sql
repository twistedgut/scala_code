/**********************************************
* Add NOT NULL constraint: price_default.currency_id
*
* TjG, October 2007
**********************************************/

---------------------------------------------------------------------------
-- Changes to existing schema
---------------------------------------------------------------------------
SELECT 'Adding NOT NULL constraint to column price_default.currency_id...';

BEGIN;

ALTER TABLE price_default ALTER COLUMN currency_id SET NOT NULL;

COMMIT;
