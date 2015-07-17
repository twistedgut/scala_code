-- CANDO-55: Create a section in the 'system_config' tables to support
--           turning on/off the Automatic Upload Reservation process
--           for each Sales Channel.

BEGIN WORK;

--
-- first create the group for each Sales Channel
--

INSERT INTO system_config.config_group (name,channel_id)
SELECT  'Automatic_Reservation_Upload_Upon_Stock_Updates',
        id
FROM    channel
ORDER BY id
;


--
-- Set which Sales Channels are 'On' or 'Off' by default
--      NaP & MrP are 'On'
--      Outnet & JC are 'Off'
--

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  cg.id,
        'state',
        CASE b.config_section
            WHEN 'NAP' THEN 'On'
            WHEN 'MRP' THEN 'On'
            ELSE 'Off'
        END
FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id
WHERE   cg.name = 'Automatic_Reservation_Upload_Upon_Stock_Updates'
ORDER BY cg.id
;

COMMIT WORK;
