-- CANDO-576: Turns On Sending Email Alerts and Enabling the 'Premier Delivery' Subject

BEGIN WORK;

-- Enable sending of SMS & Email Alerts
UPDATE  system_config.config_group_setting
    SET value   = 'On'
WHERE   config_group_id IN (
            SELECT  cg.id
            FROM    system_config.config_group cg
                    JOIN channel ch ON ch.id = cg.channel_id
                    JOIN business b ON b.id = ch.business_id
                                    AND b.config_section IN ( 'NAP','MRP' )
            WHERE   cg.name = 'Premier_Delivery'
        )
AND     setting IN ('Email Alert')
;

-- Enabled the Correspondence Subjects
UPDATE  correspondence_subject
    SET enabled = TRUE
WHERE   channel_id IN (
            SELECT  ch.id
            FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                  AND b.config_section IN ( 'NAP','MRP' )
        )
;

-- Disable the 'SMS' Correspondence Methods
-- As this is not going to be usable for DC2
UPDATE  correspondence_method
    SET enabled = FALSE
WHERE   method = 'SMS'
;

COMMIT WORK;
