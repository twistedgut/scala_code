-- CANDO-685: Updates the 'return_cutoff_days' column in
--            the 'shipping_account' table, to be at least
--            28 days for each account, it was 14 days

BEGIN WORK;

UPDATE  shipping_account
    SET return_cutoff_days  = return_cutoff_days + 14
WHERE   return_cutoff_days IS NOT NULL
AND     return_cutoff_days < 28
;

COMMIT WORK;
