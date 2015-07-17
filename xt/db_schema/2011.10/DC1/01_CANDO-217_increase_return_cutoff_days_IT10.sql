-- CANDO-217: Increase the 'return_cutoff_days' on the 'shipping_account' table
--            to be 14 days from delivery, so first take 7 off the current then add 14

BEGIN WORK;

UPDATE  shipping_account
    SET return_cutoff_days  = ( return_cutoff_days - 7 ) + 14
WHERE   return_cutoff_days IS NOT NULL
;

COMMIT WORK;
