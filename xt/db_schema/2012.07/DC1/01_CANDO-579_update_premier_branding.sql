-- CANDO-579: Update the Premier Brand in the 'channel_branding' table

BEGIN WORK;

-- Insert Missing Channel Premier Brand as 'London Premier'
INSERT INTO channel_branding (channel_id, branding_id, value )
SELECT  ch.id,
        brand.id,
        'London Premier'
FROM    channel ch
            JOIN business b ON b.id = ch.business_id
                            AND b.config_section IN ('OUTNET','JC'),
        branding brand
WHERE   brand.code = 'PREM_NAME'
ORDER BY ch.id
;


-- Update the Channels to have the correct Branding
UPDATE  channel_branding
    SET value   =
                    CASE    (
                                SELECT  b.config_section
                                FROM    channel ch
                                            JOIN business b ON b.id = ch.business_id
                                WHERE   ch.id = channel_id
                            )
                        WHEN 'NAP' THEN 'Net-A-Porter Premier'
                        WHEN 'OUTNET' THEN 'THE OUTNET Premier'
                        WHEN 'MRP' THEN 'Mr Porter Premier'
                        ELSE value
                    END
WHERE   channel_id IN (
                SELECT  ch.id
                FROM    channel ch
                            JOIN business b ON b.id = ch.business_id
                                            AND b.config_section IN ( 'NAP', 'OUTNET', 'MRP' )
            )
AND     branding_id IN (
                SELECT  brand.id
                FROM    branding brand
                WHERE   brand.code = 'PREM_NAME'
            )
;


COMMIT WORK;
