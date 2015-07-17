-- CANDO-217: Remove the Dodgy 'Unknown' 'shipping_account' record for Mr. P that is set to 7 days

BEGIN WORK;

DELETE FROM shipping_account
WHERE name = 'Unknown'
AND channel_id = 6
AND return_cutoff_days = 7
;

COMMIT WORK;
