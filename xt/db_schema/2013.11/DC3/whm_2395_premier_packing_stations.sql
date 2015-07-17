-- Add Premier packing-stations/printers to DC3

BEGIN;

-- The packing stations
INSERT INTO system_config.config_group (name) VALUES
    ('PremierStation_01'),
    ('PremierStation_02'),
    ('PremierStation_03'),
    ('PremierStation_04')
;

-- Assign packing stations to packing station list
INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PremierStation_01', 1001 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PremierStation_01', 1001 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PremierStation_01', 1001 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PremierStation_01', 1001 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PremierStation_02', 1002 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PremierStation_02', 1002 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PremierStation_02', 1002 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PremierStation_02', 1002 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PremierStation_03', 1003 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PremierStation_03', 1003 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PremierStation_03', 1003 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PremierStation_03', 1003 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PremierStation_04', 1004 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PremierStation_04', 1004 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PremierStation_04', 1004 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PremierStation_04', 1004 )
;

-- Assign new document printers
INSERT INTO system_config.config_group_setting (config_group_id, setting, value ) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_01'), 'doc_printer', 'HKP_Doc_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_01'), 'card_printer', 'HKP_CRD_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_02'), 'doc_printer', 'HKP_Doc_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_02'), 'card_printer', 'HKP_CRD_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_03'), 'doc_printer', 'HKP_Doc_2' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_03'), 'card_printer', 'HKP_CRD_2' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_04'), 'doc_printer', 'HKP_Doc_2' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PremierStation_04'), 'card_printer', 'HKP_CRD_2' )
;

COMMIT;
