-- CANDO-80: Turn Off Email & SMS Communication for Premier Delivery
--           This is so we can put functionality live without it being 'ON'

BEGIN WORK;

UPDATE  system_config.config_group_setting
    SET value   = 'Off'
WHERE   config_group_id IN (
            SELECT  cg.id
            FROM    system_config.config_group cg
            WHERE   cg.name = 'Premier_Delivery'
        )
AND     setting IN ('SMS Alert', 'Email Alert' )
;

COMMIT WORK;
