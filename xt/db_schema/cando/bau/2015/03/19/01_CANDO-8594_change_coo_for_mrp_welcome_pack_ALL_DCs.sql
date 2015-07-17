-- All DCs

-- CANDO-8594: Update the Country of Origin for the MRP
--             Welcome Pack to be 'China'

BEGIN WORK;

UPDATE  promotion_type
    SET origin = 'China'
WHERE   channel_id = (
    SELECT  ch.id
    FROM    channel ch
            JOIN business b ON             b.id = ch.business_id
                           AND b.config_section = 'MRP'
)
AND     name   = 'Welcome Pack - English'
AND     origin = 'United Kingdom'
;

COMMIT WORK;
