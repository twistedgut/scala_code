--
-- For DC1 & DC2 only
--

-- CANDO-7896: Enable French & German Languages to
--             be used by the CMS for Jimmy Choo

BEGIN WORK;

UPDATE  system_config.config_group_setting
    SET value = 'On'
WHERE   config_group_id IN (
    SELECT  scg.id
    FROM    system_config.config_group scg
                JOIN channel ch ON ch.id = scg.channel_id
                JOIN business b ON b.id  = ch.business_id
                               AND b.config_section = 'JC'
    WHERE   scg.name = 'Language'
)
AND     setting IN ( 'FR', 'DE' )
;

COMMIT WORK;
