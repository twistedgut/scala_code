-- Populate account_number & shipper_number fileds in shipping_account table

BEGIN WORK;

-- Domestic Account

UPDATE shipping_account
    SET account_number  = '3xa057',
        shipping_number = '3XA051'
WHERE name = 'Domestic'
AND channel_id = (
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

UPDATE shipping_account
    SET account_number  = '359528',
        shipping_number = '539522'
WHERE name = 'Domestic'
AND channel_id = (
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

-- International Account

UPDATE shipping_account
    SET account_number  = '3xa058',
        shipping_number = '3XA051'
WHERE name = 'International'
AND channel_id = (
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

UPDATE shipping_account
    SET account_number  = '359529',
        shipping_number = '539522'
WHERE name = 'International'
AND channel_id = (
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
