-- CANDO-1526: Updates Jimmy Choo's brand name to be accurate
--             even though Jimmy Choo is not used yet it still
--             should be correct.

BEGIN WORK;

UPDATE  channel_branding
    SET value   = 'J.CHOO (OS) Limited'
WHERE   branding_id = (
            SELECT  id
            FROM    branding
            WHERE   code = 'DOC_HEADING'
        )
AND     channel_id = (
            SELECT  c.id
            FROM    channel c
                        JOIN business b ON b.id = c.business_id
            WHERE   b.config_section = 'JC'
        )
;

COMMIT WORK;
