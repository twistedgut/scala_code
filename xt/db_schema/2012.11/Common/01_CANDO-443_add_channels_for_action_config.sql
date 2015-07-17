-- CANDO-443: Add new section to the System Config tables
--            called 'ChannelsForAction' and populate its Settings

BEGIN WORK;

-- create the Config Group
INSERT INTO system_config.config_group (name) VALUES ('ChannelsForAction');

-- create the Config Group Settings
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES
(
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'ChannelsForAction'
        AND     channel_id IS NULL
    ),
    'Reservation/Upload',
    'NAP',
    1
),
(
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'ChannelsForAction'
        AND     channel_id IS NULL
    ),
    'Reservation/Upload',
    'MRP',
    2
)
;


COMMIT WORK;
