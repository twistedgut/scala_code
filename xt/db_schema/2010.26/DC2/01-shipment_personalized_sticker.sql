BEGIN;

INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('personalized_stickers', 2, false );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, active )
SELECT currval('system_config.config_group_id_seq'), 'display_sticker_in_xtracker', 1, false;

INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('personalized_stickers', 4, false );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, active )
SELECT currval('system_config.config_group_id_seq'), 'display_sticker_in_xtracker', 1, false;

INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('personalized_stickers', 6, true );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, active )
SELECT currval('system_config.config_group_id_seq'), 'display_sticker_in_xtracker', 1, true;

COMMIT;