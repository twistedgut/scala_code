-- printer config settings for JC, channel id 7
-- we're just copying what's there for channels 1 and 3 at the moment

BEGIN;

INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'PrinterStationListReturnsIn',7,true
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
        WHERE name='PrinterStationListReturnsIn'
        AND channel_id = 1
    )
;

INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'PrinterStationListReturnsQC',7,true
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
        WHERE name='PrinterStationListReturnsQC'
        AND channel_id = 1
    )
;

COMMIT;
