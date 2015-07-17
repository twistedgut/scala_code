-- CANDO-696: Turns On Pre-Order for NaP
--            in the System Config tables

BEGIN WORK;

UPDATE  system_config.config_group_setting
    SET value   = '1'
WHERE   setting = 'is_active'
AND     config_group_id = (
            SELECT  cg.id
            FROM    system_config.config_group cg
                        JOIN channel ch ON ch.id = cg.channel_id
                        JOIN business b ON b.id = ch.business_id
                                        AND b.config_section = 'NAP'
            WHERE   cg.name = 'PreOrder'
        )
;

COMMIT WORK;
