-- CANDO-579: Uppercase the Premier Branding for NAP & MRP

BEGIN WORK;

UPDATE channel_branding
    SET value   = 
                    CASE    (
                                SELECT  b.config_section
                                FROM    channel ch
                                            JOIN business b ON b.id = ch.business_id
                                WHERE   ch.id = channel_id
                            )
                        WHEN 'NAP' THEN 'NET-A-PORTER Premier'
                        WHEN 'MRP' THEN 'MR PORTER Premier'
                        ELSE value
                    END
WHERE   channel_id IN (
                SELECT  ch.id
                FROM    channel ch
                            JOIN business b ON b.id = ch.business_id
                                            AND b.config_section IN ( 'NAP', 'MRP' )
            )
AND     branding_id IN (
                SELECT  brand.id
                FROM    branding brand
                WHERE   brand.code = 'PREM_NAME'
            )
;

COMMIT WORK;
