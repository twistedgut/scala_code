-- CANDO-576: Turn's On Premier Email Alerts for NAP & MRP

BEGIN WORK;

-- Enabled the Correspondence Subjects
UPDATE  correspondence_subject
    SET enabled = TRUE
WHERE subject = 'Premier Delivery'
AND channel_id IN (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                    AND b.config_section IN ( 'NAP','MRP' )
    )
;

-- Disable Sending Emails for Premier Alerts
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

COMMIT WORK;
