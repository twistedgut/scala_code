-- packing station config settings for JC, channel id 8
-- we're just copying what's there for channels 1 and 3 at the moment

BEGIN;

DELETE FROM system_config.config_group
WHERE name = 'PackingStationList' AND channel_id = 8;

INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'PackingStationList',8,true
);

INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value, sequence, active
)
SELECT
    currval('system_config.config_group_id_seq'), setting, value, sequence, active
    FROM system_config.config_group_setting
    WHERE config_group_id = (
        SELECT id
        FROM system_config.config_group
        WHERE name = 'PackingStationList'
        AND channel_id = 2
    )
;

COMMIT;
