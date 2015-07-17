-- CANDO-576: Disables the Correspondence Subject records for
--            Premier Routing so that initially DC2 doesn't send out
--            Premir Routing Alerts. To be turned back on via a BAU.

BEGIN WORK;

-- Disable Sending Emails for Premier Alerts
UPDATE  system_config.config_group_setting
    SET value   = 'Off'
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
    SET enabled = FALSE
WHeRE subject = 'Premier Delivery'
;

COMMIT WORK;
