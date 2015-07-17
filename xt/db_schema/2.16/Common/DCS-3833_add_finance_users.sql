-- DCS-3833: Adds a list of users that are the only people which have access to
--           the 'Update Fulfilled' button on the Order View page into the
--           'system_config' schema tables.

BEGIN WORK;

-- First set-up the user group
INSERT INTO system_config.config_group VALUES (
    default,
    'Finance_Manager_Users',
    null,
    default
)
;

-- Second set-up the users themselves
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    'k.cole',
    1
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    'n.brown',
    2
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    'e.caviedes',
    3
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    's.lewis',
    4
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    'r.mills',
    5
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Finance_Manager_Users'),
    'user',
    's.chellew',
    6
)
;

COMMIT WORK;
