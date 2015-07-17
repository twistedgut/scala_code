-- CANDO-1588: Disables the Correspondence Subject records for
--             Premier Routing so that DC3 does not send out SMS
--             for Premier Routing Alerts.

BEGIN WORK;

-- Disable Sending SMS for Premier Alerts
UPDATE  system_config.config_group_setting
    SET value   = 'Off'
WHERE   config_group_id IN (
            SELECT  cg.id
            FROM    system_config.config_group cg
                    JOIN channel ch ON ch.id = cg.channel_id
                    JOIN business b ON b.id = ch.business_id
                                    AND b.config_section IN ( 'NAP','MRP','OUTNET','JC' )
            WHERE   cg.name = 'Premier_Delivery'
        )
AND     setting IN ('SMS Alert');


COMMIT WORK;
