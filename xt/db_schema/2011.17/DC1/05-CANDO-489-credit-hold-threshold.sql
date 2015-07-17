--
-- CANDO-489
--

BEGIN TRANSACTION;

--
-- update the credit hold threshold values 
--

-- order total value for NAP =2500
UPDATE credit_hold_threshold
    SET value=2500
WHERE name='Single Order Value'
AND channel_id = (
        SELECT id FROM channel WHERE
        web_name='NAP-INTL' AND
        name='NET-A-PORTER.COM'
    );

-- order total value for MRP =1000
UPDATE credit_hold_threshold
    SET value=1000
WHERE name='Single Order Value'
AND channel_id = (
            SELECT id FROM channel WHERE
            web_name='MRP-INTL' AND
            name='MRPORTER.COM'
    );

-- order total value for OUT =1000
UPDATE credit_hold_threshold
    SET value=1000
WHERE name='Single Order Value'
AND channel_id = (
             SELECT id FROM channel WHERE
             web_name='OUTNET-INTL' AND
             name='theOutnet.com'
    );

--6 months spend limit for NAP = 999999
UPDATE credit_hold_threshold
    SET value=999999
WHERE name='Total Order Value'
AND channel_id =(
            SELECT id FROM channel WHERE
            web_name='NAP-INTL' AND
            name='NET-A-PORTER.COM'
    );

--1 week spend limit for NAP = 9999999 
UPDATE credit_hold_threshold
    SET value=999999
WHERE name='Weekly Order Value'
AND channel_id =(
             SELECT id FROM channel WHERE
             web_name='NAP-INTL' AND
             name='NET-A-PORTER.COM'
    );
COMMIT WORK;
