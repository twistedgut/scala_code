-- DCS-2828: Add a new group to system_config.config_group & system_config.config_group_setting for a switch to effect the working of
-- Carrier Automation it can be set to one of these 3 states: 'On', 'Off', 'Import_Off_Only'. This patch will set the switch to 'Off'.
-- There will be one switch per Sales Channel.

BEGIN WORK;

-- Set up NAP's Group
INSERT INTO system_config.config_group (name,channel_id) VALUES (
    'Carrier_Automation_State',
    (SELECT c.id
     FROM   channel c
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'NAP'
    )
)
;
-- Set up OUTNET's Group
INSERT INTO system_config.config_group (name,channel_id) VALUES (
    'Carrier_Automation_State',
    (SELECT c.id
     FROM   channel c
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'OUTNET'
    )
)
;

-- Set NAP's State to be 'Off' by Default.
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (SELECT cg.id
     FROM   system_config.config_group cg
            JOIN channel c ON c.id = cg.channel_id
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'NAP'
     WHERE  cg.name = 'Carrier_Automation_State'
    ),
    'state',
    'Off'
)
;
-- Set OUTNET's State to be 'Off' by Default.
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (SELECT cg.id
     FROM   system_config.config_group cg
            JOIN channel c ON c.id = cg.channel_id
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'OUTNET'
     WHERE  cg.name = 'Carrier_Automation_State'
    ),
    'state',
    'Off'
)
;

COMMIT WORK;
