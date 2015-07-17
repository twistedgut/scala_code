

BEGIN;

-- Add new packing stations
INSERT INTO system_config.config_group (name) VALUES
    ('PackingStation_45'),
    ('PackingStation_46'),
    ('PackingStation_47'),
    ('PackingStation_48'),
    ('PackingStation_49'),
    ('PackingStation_50'),
    ('PackingStation_51'),
    ('PackingStation_52'),
    ('PackingStation_53'),
    ('PackingStation_54'),
    ('PackingStation_55'),
    ('PackingStation_56')
;

--Assign packing stations to packing station list
INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_45', 45),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_45', 45 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_45', 45 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_45', 45 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_46', 46 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_46', 46 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_46', 46 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_46', 46 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_47', 47 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_47', 47 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_47', 47 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_47', 47 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_48', 48 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_48', 48 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_48', 48 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_48', 48 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_49', 49 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_49', 49 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_49', 49 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_49', 49 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_50', 50 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_50', 50 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_50', 50 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_50', 50 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_51', 51 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_51', 51 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_51', 51 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_51', 51 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_52', 52 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_52', 52 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_52', 52 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_52', 52 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_53', 53 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_53', 53 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_53', 53 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_53', 53 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_54', 54 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_54', 54 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_54', 54 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_54', 54 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_55', 55 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_55', 55 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_55', 55 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_55', 55 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'packing_station', 'PackingStation_56', 56 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'packing_station', 'PackingStation_56', 56 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'packing_station', 'PackingStation_56', 56 ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')), 'packing_station', 'PackingStation_56', 56 )
;

--Assign new document printers
INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_45'), 'doc_printer', 'Packing Doc Prn 23' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_45'), 'lab_printer', 'Packing Lab Prn 45' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_46'), 'doc_printer', 'Packing Doc Prn 23' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_46'), 'lab_printer', 'Packing Lab Prn 46' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_47'), 'doc_printer', 'Packing Doc Prn 24' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_47'), 'lab_printer', 'Packing Lab Prn 47' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_48'), 'doc_printer', 'Packing Doc Prn 24' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_48'), 'lab_printer', 'Packing Lab Prn 48' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_49'), 'doc_printer', 'Packing Doc Prn 25' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_49'), 'lab_printer', 'Packing Lab Prn 49' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_50'), 'doc_printer', 'Packing Doc Prn 25' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_50'), 'lab_printer', 'Packing Lab Prn 50' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_51'), 'doc_printer', 'Packing Doc Prn 26' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_51'), 'lab_printer', 'Packing Lab Prn 51' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_52'), 'doc_printer', 'Packing Doc Prn 26' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_52'), 'lab_printer', 'Packing Lab Prn 52' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_53'), 'doc_printer', 'Packing Doc Prn 27' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_53'), 'lab_printer', 'Packing Lab Prn 53' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_54'), 'doc_printer', 'Packing Doc Prn 27' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_54'), 'lab_printer', 'Packing Lab Prn 54' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_55'), 'doc_printer', 'Packing Doc Prn 28' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_55'), 'lab_printer', 'Packing Lab Prn 55' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_56'), 'doc_printer', 'Packing Doc Prn 28' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_56'), 'lab_printer', 'Packing Lab Prn 56' )
;

COMMIT;
