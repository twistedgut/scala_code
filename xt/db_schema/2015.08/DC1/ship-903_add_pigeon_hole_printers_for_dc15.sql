-- New pigeon hole document printers for DC1.5

BEGIN;

INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
((SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters'), 'Picking Premier Address Card 91', 'u9_premiercard_pick_91'),
((SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters'), 'Picking Premier Address Card 92', 'u9_premiercard_pick_92');

COMMIT;
