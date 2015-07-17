-- This populates the 'return_account_number' field on the 'shipping_account' table

BEGIN WORK;

-- update for NAP
UPDATE shipping_account
    SET return_account_number   = '3XA051'
WHERE channel_id = (
        SELECT  c.id
        FROM    channel c
                JOIN business b ON b.id = c.business_id
        WHERE   b.config_section = 'NAP'
    )
AND carrier_id IN (
        SELECT  id
        FROM    carrier
        WHERE   name = 'UPS'
    )
;

-- update for OUTNET
UPDATE shipping_account
    SET return_account_number   = '539522'
WHERE channel_id = (
        SELECT  c.id
        FROM    channel c
                JOIN business b ON b.id = c.business_id
        WHERE   b.config_section = 'OUTNET'
    )
AND carrier_id IN (
        SELECT  id
        FROM    carrier
        WHERE   name = 'UPS'
    )
;

COMMIT WORK;
