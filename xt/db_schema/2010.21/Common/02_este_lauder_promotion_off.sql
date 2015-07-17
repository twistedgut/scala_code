BEGIN;

INSERT INTO system_config.config_group
(name, active)
VALUES
('Promotions', true);

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, active)
VALUES
(
( SELECT id FROM system_config.config_group WHERE name = 'Promotions' ),
'Este Lauder', 'Off', true
);

COMMIT;
