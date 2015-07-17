-- CANDO-3097: Turn Off 'SMS' Premier Communications

BEGIN WORK;

--
-- Turn Off SMS for NAP only
--
UPDATE system_config.config_group_setting
    SET value = 'Off'
WHERE   setting = 'SMS Alert'
AND     config_group_id = (
    SELECT  sccg.id
    FROM    system_config.config_group sccg
            JOIN channel c  ON c.id = sccg.channel_id
            JOIN business b ON b.id = c.business_id
                           AND b.config_section = 'NAP'
    WHERE   sccg.name = 'Premier_Delivery'
)
;

--
-- Turn Off the SMS Correspondence Method
--
UPDATE  correspondence_method
    SET enabled = FALSE
WHERE   method = 'SMS'
;

COMMIT WORK;
