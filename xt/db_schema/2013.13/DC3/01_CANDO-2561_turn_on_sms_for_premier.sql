-- CANDO-2561: Turn On 'SMS' Premier Communications

BEGIN WORK;

--
-- Update the 'send_hold_alert_threshold' value to 3
-- for ALL Sales Channels
--
UPDATE system_config.config_group_setting
    SET value = 3
WHERE   setting = 'send_hold_alert_threshold'
AND     config_group_id IN (
    SELECT  id
    FROM    system_config.config_group
    WHERE   name = 'Premier_Delivery'
);

--
-- Turn on SMS for NAP only
--
UPDATE system_config.config_group_setting
    SET value = 'On'
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
-- Turn on the SMS Correspondence Method
--
UPDATE  correspondence_method
    SET enabled = TRUE
WHERE   method = 'SMS'
;

COMMIT WORK;
