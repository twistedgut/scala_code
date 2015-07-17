BEGIN;

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_101');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_101',
         101);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_101',
         101);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_101',
         101);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_101',
         101);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_101' ),
         'doc_printer', 'Packing Doc Prn 101' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_101' ),
         'lab_printer', 'Packing Lab Prn 101' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_102');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_102',
         102);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_102',
         102);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_102',
         102);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_102',
         102);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_102' ),
         'doc_printer', 'Packing Doc Prn 101' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_102' ),
         'lab_printer', 'Packing Lab Prn 102' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_103');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_103',
         103);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_103',
         103);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_103',
         103);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_103',
         103);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_103' ),
         'doc_printer', 'Packing Doc Prn 101' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_103' ),
         'lab_printer', 'Packing Lab Prn 103' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_104');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_104',
         104);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_104',
         104);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_104',
         104);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_104',
         104);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_104' ),
         'doc_printer', 'Packing Doc Prn 102' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_104' ),
         'lab_printer', 'Packing Lab Prn 104' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_105');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_105',
         105);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_105',
         105);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_105',
         105);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_105',
         105);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_105' ),
         'doc_printer', 'Packing Doc Prn 102' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_105' ),
         'lab_printer', 'Packing Lab Prn 105' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_106');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_106',
         106);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_106',
         106);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_106',
         106);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_106',
         106);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_106' ),
         'doc_printer', 'Packing Doc Prn 103' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_106' ),
         'lab_printer', 'Packing Lab Prn 106' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_107');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_107',
         107);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_107',
         107);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_107',
         107);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_107',
         107);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_107' ),
         'doc_printer', 'Packing Doc Prn 103' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_107' ),
         'lab_printer', 'Packing Lab Prn 107' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_108');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_108',
         108);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_108',
         108);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_108',
         108);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_108',
         108);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_108' ),
         'doc_printer', 'Packing Doc Prn 104' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_108' ),
         'lab_printer', 'Packing Lab Prn 108' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_109');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_109',
         109);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_109',
         109);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_109',
         109);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_109',
         109);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_109' ),
         'doc_printer', 'Packing Doc Prn 104' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_109' ),
         'lab_printer', 'Packing Lab Prn 109' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_110');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_110',
         110);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_110',
         110);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_110',
         110);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_110',
         110);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_110' ),
         'doc_printer', 'Packing Doc Prn 104' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_110' ),
         'lab_printer', 'Packing Lab Prn 110' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_111');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_111',
         111);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_111',
         111);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_111',
         111);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_111',
         111);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_111' ),
         'doc_printer', 'Packing Doc Prn 105' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_111' ),
         'lab_printer', 'Packing Lab Prn 111' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_112');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_112',
         112);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_112',
         112);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_112',
         112);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_112',
         112);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_112' ),
         'doc_printer', 'Packing Doc Prn 105' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_112' ),
         'lab_printer', 'Packing Lab Prn 112' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_113');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_113',
         113);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_113',
         113);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_113',
         113);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_113',
         113);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_113' ),
         'doc_printer', 'Packing Doc Prn 106' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_113' ),
         'lab_printer', 'Packing Lab Prn 113' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_114');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_114',
         114);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_114',
         114);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_114',
         114);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_114',
         114);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_114' ),
         'doc_printer', 'Packing Doc Prn 106' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_114' ),
         'lab_printer', 'Packing Lab Prn 114' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_115');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_115',
         115);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_115',
         115);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_115',
         115);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_115',
         115);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_115' ),
         'doc_printer', 'Packing Doc Prn 107' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_115' ),
         'lab_printer', 'Packing Lab Prn 115' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_116');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_116',
         116);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_116',
         116);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_116',
         116);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_116',
         116);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_116' ),
         'doc_printer', 'Packing Doc Prn 107' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_116' ),
         'lab_printer', 'Packing Lab Prn 116' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_117');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_117',
         117);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_117',
         117);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_117',
         117);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_117',
         117);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_117' ),
         'doc_printer', 'Packing Doc Prn 107' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_117' ),
         'lab_printer', 'Packing Lab Prn 117' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_118');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_118',
         118);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_118',
         118);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_118',
         118);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_118',
         118);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_118' ),
         'doc_printer', 'Packing Doc Prn 108' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_118' ),
         'lab_printer', 'Packing Lab Prn 118' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_119');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_119',
         119);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_119',
         119);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_119',
         119);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_119',
         119);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_119' ),
         'doc_printer', 'Packing Doc Prn 108' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_119' ),
         'lab_printer', 'Packing Lab Prn 119' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_120');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_120',
         120);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_120',
         120);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_120',
         120);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_120',
         120);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_120' ),
         'doc_printer', 'Packing Doc Prn 109' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_120' ),
         'lab_printer', 'Packing Lab Prn 120' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_121');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_121',
         121);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_121',
         121);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_121',
         121);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_121',
         121);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_121' ),
         'doc_printer', 'Packing Doc Prn 109' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_121' ),
         'lab_printer', 'Packing Lab Prn 121' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_122');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_122',
         122);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_122',
         122);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_122',
         122);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_122',
         122);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_122' ),
         'doc_printer', 'Packing Doc Prn 110' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_122' ),
         'lab_printer', 'Packing Lab Prn 122' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_123');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_123',
         123);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_123',
         123);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_123',
         123);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_123',
         123);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_123' ),
         'doc_printer', 'Packing Doc Prn 110' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_123' ),
         'lab_printer', 'Packing Lab Prn 123' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_124');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_124',
         124);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_124',
         124);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_124',
         124);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_124',
         124);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_124' ),
         'doc_printer', 'Packing Doc Prn 111' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_124' ),
         'lab_printer', 'Packing Lab Prn 124' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_125');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_125',
         125);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_125',
         125);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_125',
         125);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_125',
         125);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_125' ),
         'doc_printer', 'Packing Doc Prn 111' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_125' ),
         'lab_printer', 'Packing Lab Prn 125' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_126');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_126',
         126);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_126',
         126);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_126',
         126);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_126',
         126);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_126' ),
         'doc_printer', 'Packing Doc Prn 112' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_126' ),
         'lab_printer', 'Packing Lab Prn 126' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_127');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_127',
         127);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_127',
         127);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_127',
         127);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_127',
         127);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_127' ),
         'doc_printer', 'Packing Doc Prn 112' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_127' ),
         'lab_printer', 'Packing Lab Prn 127' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_128');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_128',
         128);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_128',
         128);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_128',
         128);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_128',
         128);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_128' ),
         'doc_printer', 'Packing Doc Prn 112' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_128' ),
         'lab_printer', 'Packing Lab Prn 128' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_129');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_129',
         129);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_129',
         129);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_129',
         129);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_129',
         129);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_129' ),
         'doc_printer', 'Packing Doc Prn 113' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_129' ),
         'lab_printer', 'Packing Lab Prn 129' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_130');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_130',
         130);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_130',
         130);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_130',
         130);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_130',
         130);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_130' ),
         'doc_printer', 'Packing Doc Prn 113' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_130' ),
         'lab_printer', 'Packing Lab Prn 130' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_131');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_131',
         131);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_131',
         131);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_131',
         131);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_131',
         131);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_131' ),
         'doc_printer', 'Packing Doc Prn 114' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_131' ),
         'lab_printer', 'Packing Lab Prn 131' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_132');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_132',
         132);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_132',
         132);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_132',
         132);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_132',
         132);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_132' ),
         'doc_printer', 'Packing Doc Prn 114' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_132' ),
         'lab_printer', 'Packing Lab Prn 132' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_133');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_133',
         133);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_133',
         133);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_133',
         133);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_133',
         133);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_133' ),
         'doc_printer', 'Packing Doc Prn 115' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_133' ),
         'lab_printer', 'Packing Lab Prn 133' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_134');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_134',
         134);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_134',
         134);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_134',
         134);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_134',
         134);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_134' ),
         'doc_printer', 'Packing Doc Prn 115' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_134' ),
         'lab_printer', 'Packing Lab Prn 134' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_135');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_135',
         135);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_135',
         135);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_135',
         135);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_135',
         135);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_135' ),
         'doc_printer', 'Packing Doc Prn 116' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_135' ),
         'lab_printer', 'Packing Lab Prn 135' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_136');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_136',
         136);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_136',
         136);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_136',
         136);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_136',
         136);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_136' ),
         'doc_printer', 'Packing Doc Prn 116' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_136' ),
         'lab_printer', 'Packing Lab Prn 136' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_137');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_137',
         137);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_137',
         137);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_137',
         137);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_137',
         137);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_137' ),
         'doc_printer', 'Packing Doc Prn 117' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_137' ),
         'lab_printer', 'Packing Lab Prn 137' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_138');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_138',
         138);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_138',
         138);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_138',
         138);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_138',
         138);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_138' ),
         'doc_printer', 'Packing Doc Prn 117' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_138' ),
         'lab_printer', 'Packing Lab Prn 138' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_139');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_139',
         139);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_139',
         139);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_139',
         139);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_139',
         139);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_139' ),
         'doc_printer', 'Packing Doc Prn 117' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_139' ),
         'lab_printer', 'Packing Lab Prn 139' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_140');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_140',
         140);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_140',
         140);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_140',
         140);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_140',
         140);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_140' ),
         'doc_printer', 'Packing Doc Prn 118' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_140' ),
         'lab_printer', 'Packing Lab Prn 140' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_141');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_141',
         141);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_141',
         141);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_141',
         141);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_141',
         141);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_141' ),
         'doc_printer', 'Packing Doc Prn 118' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_141' ),
         'lab_printer', 'Packing Lab Prn 141' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_142');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_142',
         142);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_142',
         142);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_142',
         142);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_142',
         142);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_142' ),
         'doc_printer', 'Packing Doc Prn 119' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_142' ),
         'lab_printer', 'Packing Lab Prn 142' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_143');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_143',
         143);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_143',
         143);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_143',
         143);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_143',
         143);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_143' ),
         'doc_printer', 'Packing Doc Prn 119' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_143' ),
         'lab_printer', 'Packing Lab Prn 143' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_144');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_144',
         144);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_144',
         144);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_144',
         144);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_144',
         144);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_144' ),
         'doc_printer', 'Packing Doc Prn 120' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_144' ),
         'lab_printer', 'Packing Lab Prn 144' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_145');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_145',
         145);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_145',
         145);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_145',
         145);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_145',
         145);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_145' ),
         'doc_printer', 'Packing Doc Prn 120' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_145' ),
         'lab_printer', 'Packing Lab Prn 145' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_146');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_146',
         146);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_146',
         146);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_146',
         146);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_146',
         146);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_146' ),
         'doc_printer', 'Packing Doc Prn 121' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_146' ),
         'lab_printer', 'Packing Lab Prn 146' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_147');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_147',
         147);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_147',
         147);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_147',
         147);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_147',
         147);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_147' ),
         'doc_printer', 'Packing Doc Prn 121' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_147' ),
         'lab_printer', 'Packing Lab Prn 147' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_148');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_148',
         148);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_148',
         148);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_148',
         148);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_148',
         148);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_148' ),
         'doc_printer', 'Packing Doc Prn 122' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_148' ),
         'lab_printer', 'Packing Lab Prn 148' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_149');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_149',
         149);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_149',
         149);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_149',
         149);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_149',
         149);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_149' ),
         'doc_printer', 'Packing Doc Prn 122' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_149' ),
         'lab_printer', 'Packing Lab Prn 149' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_150');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_150',
         150);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_150',
         150);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_150',
         150);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_150',
         150);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_150' ),
         'doc_printer', 'Packing Doc Prn 122' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_150' ),
         'lab_printer', 'Packing Lab Prn 150' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_151');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_151',
         151);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_151',
         151);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_151',
         151);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_151',
         151);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_151' ),
         'doc_printer', 'Packing Doc Prn 123' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_151' ),
         'lab_printer', 'Packing Lab Prn 151' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_152');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_152',
         152);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_152',
         152);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_152',
         152);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_152',
         152);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_152' ),
         'doc_printer', 'Packing Doc Prn 123' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_152' ),
         'lab_printer', 'Packing Lab Prn 152' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_153');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_153',
         153);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_153',
         153);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_153',
         153);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_153',
         153);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_153' ),
         'doc_printer', 'Packing Doc Prn 124' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_153' ),
         'lab_printer', 'Packing Lab Prn 153' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_154');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_154',
         154);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_154',
         154);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_154',
         154);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_154',
         154);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_154' ),
         'doc_printer', 'Packing Doc Prn 124' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_154' ),
         'lab_printer', 'Packing Lab Prn 154' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_155');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_155',
         155);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_155',
         155);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_155',
         155);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_155',
         155);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_155' ),
         'doc_printer', 'Packing Doc Prn 125' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_155' ),
         'lab_printer', 'Packing Lab Prn 155' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_156');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_156',
         156);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_156',
         156);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_156',
         156);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_156',
         156);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_156' ),
         'doc_printer', 'Packing Doc Prn 125' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_156' ),
         'lab_printer', 'Packing Lab Prn 156' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_157');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_157',
         157);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_157',
         157);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_157',
         157);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_157',
         157);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_157' ),
         'doc_printer', 'Packing Doc Prn 126' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_157' ),
         'lab_printer', 'Packing Lab Prn 157' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_158');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_158',
         158);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_158',
         158);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_158',
         158);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_158',
         158);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_158' ),
         'doc_printer', 'Packing Doc Prn 126' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_158' ),
         'lab_printer', 'Packing Lab Prn 158' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_159');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_159',
         159);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_159',
         159);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_159',
         159);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_159',
         159);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_159' ),
         'doc_printer', 'Packing Doc Prn 127' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_159' ),
         'lab_printer', 'Packing Lab Prn 159' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_160');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_160',
         160);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_160',
         160);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_160',
         160);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_160',
         160);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_160' ),
         'doc_printer', 'Packing Doc Prn 127' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_160' ),
         'lab_printer', 'Packing Lab Prn 160' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_161');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_161',
         161);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_161',
         161);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_161',
         161);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_161',
         161);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_161' ),
         'doc_printer', 'Packing Doc Prn 127' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_161' ),
         'lab_printer', 'Packing Lab Prn 161' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_162');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_162',
         162);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_162',
         162);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_162',
         162);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_162',
         162);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_162' ),
         'doc_printer', 'Packing Doc Prn 128' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_162' ),
         'lab_printer', 'Packing Lab Prn 162' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_163');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_163',
         163);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_163',
         163);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_163',
         163);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_163',
         163);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_163' ),
         'doc_printer', 'Packing Doc Prn 128' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_163' ),
         'lab_printer', 'Packing Lab Prn 163' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_164');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_164',
         164);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_164',
         164);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_164',
         164);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_164',
         164);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_164' ),
         'doc_printer', 'Packing Doc Prn 129' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_164' ),
         'lab_printer', 'Packing Lab Prn 164' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_165');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_165',
         165);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_165',
         165);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_165',
         165);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_165',
         165);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_165' ),
         'doc_printer', 'Packing Doc Prn 129' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_165' ),
         'lab_printer', 'Packing Lab Prn 165' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_166');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_166',
         166);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_166',
         166);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_166',
         166);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_166',
         166);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_166' ),
         'doc_printer', 'Packing Doc Prn 130' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_166' ),
         'lab_printer', 'Packing Lab Prn 166' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_167');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_167',
         167);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_167',
         167);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_167',
         167);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_167',
         167);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_167' ),
         'doc_printer', 'Packing Doc Prn 130' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_167' ),
         'lab_printer', 'Packing Lab Prn 167' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_168');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_168',
         168);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_168',
         168);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_168',
         168);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_168',
         168);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_168' ),
         'doc_printer', 'Packing Doc Prn 131' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_168' ),
         'lab_printer', 'Packing Lab Prn 168' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_169');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_169',
         169);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_169',
         169);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_169',
         169);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_169',
         169);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_169' ),
         'doc_printer', 'Packing Doc Prn 131' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_169' ),
         'lab_printer', 'Packing Lab Prn 169' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_170');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_170',
         170);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_170',
         170);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_170',
         170);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_170',
         170);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_170' ),
         'doc_printer', 'Packing Doc Prn 132' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_170' ),
         'lab_printer', 'Packing Lab Prn 170' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_171');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_171',
         171);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_171',
         171);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_171',
         171);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_171',
         171);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_171' ),
         'doc_printer', 'Packing Doc Prn 132' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_171' ),
         'lab_printer', 'Packing Lab Prn 171' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_172');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_172',
         172);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_172',
         172);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_172',
         172);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_172',
         172);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_172' ),
         'doc_printer', 'Packing Doc Prn 132' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_172' ),
         'lab_printer', 'Packing Lab Prn 172' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_173');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_173',
         173);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_173',
         173);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_173',
         173);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_173',
         173);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_173' ),
         'doc_printer', 'Packing Doc Prn 133' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_173' ),
         'lab_printer', 'Packing Lab Prn 173' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_174');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_174',
         174);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_174',
         174);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_174',
         174);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_174',
         174);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_174' ),
         'doc_printer', 'Packing Doc Prn 133' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_174' ),
         'lab_printer', 'Packing Lab Prn 174' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_175');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_175',
         175);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_175',
         175);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_175',
         175);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_175',
         175);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_175' ),
         'doc_printer', 'Packing Doc Prn 134' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_175' ),
         'lab_printer', 'Packing Lab Prn 175' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_176');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_176',
         176);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_176',
         176);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_176',
         176);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_176',
         176);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_176' ),
         'doc_printer', 'Packing Doc Prn 134' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_176' ),
         'lab_printer', 'Packing Lab Prn 176' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_177');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_177',
         177);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_177',
         177);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_177',
         177);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_177',
         177);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_177' ),
         'doc_printer', 'Packing Doc Prn 135' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_177' ),
         'lab_printer', 'Packing Lab Prn 177' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_178');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_178',
         178);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_178',
         178);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_178',
         178);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_178',
         178);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_178' ),
         'doc_printer', 'Packing Doc Prn 135' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_178' ),
         'lab_printer', 'Packing Lab Prn 178' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_179');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_179',
         179);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_179',
         179);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_179',
         179);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_179',
         179);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_179' ),
         'doc_printer', 'Packing Doc Prn 136' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_179' ),
         'lab_printer', 'Packing Lab Prn 179' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_180');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_180',
         180);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_180',
         180);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_180',
         180);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_180',
         180);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_180' ),
         'doc_printer', 'Packing Doc Prn 136' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_180' ),
         'lab_printer', 'Packing Lab Prn 180' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_181');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_181',
         181);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_181',
         181);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_181',
         181);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_181',
         181);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_181' ),
         'doc_printer', 'Packing Doc Prn 137' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_181' ),
         'lab_printer', 'Packing Lab Prn 181' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_181' ),
         'card_printer', 'Packing AddressCard Prn 101' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_182');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_182',
         182);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_182',
         182);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_182',
         182);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_182',
         182);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_182' ),
         'doc_printer', 'Packing Doc Prn 137' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_182' ),
         'lab_printer', 'Packing Lab Prn 182' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_182' ),
         'card_printer', 'Packing AddressCard Prn 101' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_183');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_183',
         183);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_183',
         183);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_183',
         183);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_183',
         183);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_183' ),
         'doc_printer', 'Packing Doc Prn 137' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_183' ),
         'lab_printer', 'Packing Lab Prn 183' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_183' ),
         'card_printer', 'Packing AddressCard Prn 101' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_184');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_184',
         184);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_184',
         184);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_184',
         184);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_184',
         184);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_184' ),
         'doc_printer', 'Packing Doc Prn 138' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_184' ),
         'lab_printer', 'Packing Lab Prn 184' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_184' ),
         'card_printer', 'Packing AddressCard Prn 102' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_185');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_185',
         185);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_185',
         185);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_185',
         185);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_185',
         185);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_185' ),
         'doc_printer', 'Packing Doc Prn 138' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_185' ),
         'lab_printer', 'Packing Lab Prn 185' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_185' ),
         'card_printer', 'Packing AddressCard Prn 102' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_186');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_186',
         186);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_186',
         186);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_186',
         186);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_186',
         186);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_186' ),
         'doc_printer', 'Packing Doc Prn 139' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_186' ),
         'lab_printer', 'Packing Lab Prn 186' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_186' ),
         'card_printer', 'Packing AddressCard Prn 103' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_187');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_187',
         187);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_187',
         187);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_187',
         187);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_187',
         187);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_187' ),
         'doc_printer', 'Packing Doc Prn 139' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_187' ),
         'lab_printer', 'Packing Lab Prn 187' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_187' ),
         'card_printer', 'Packing AddressCard Prn 103' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_188');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_188',
         188);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_188',
         188);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_188',
         188);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_188',
         188);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_188' ),
         'doc_printer', 'Packing Doc Prn 140' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_188' ),
         'lab_printer', 'Packing Lab Prn 188' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_188' ),
         'card_printer', 'Packing AddressCard Prn 104' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_189');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_189',
         189);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_189',
         189);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_189',
         189);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_189',
         189);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_189' ),
         'doc_printer', 'Packing Doc Prn 140' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_189' ),
         'lab_printer', 'Packing Lab Prn 189' );

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_189' ),
         'card_printer', 'Packing AddressCard Prn 104' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_190');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_190',
         190);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_190',
         190);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_190',
         190);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_190',
         190);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_190' ),
         'doc_printer', 'Packing Doc Prn 141' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_190' ),
         'lab_printer', 'Packing Lab Prn 190' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_191');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_191',
         191);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_191',
         191);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_191',
         191);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_191',
         191);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_191' ),
         'doc_printer', 'Packing Doc Prn 141' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_191' ),
         'lab_printer', 'Packing Lab Prn 191' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_192');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_192',
         192);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_192',
         192);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_192',
         192);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_192',
         192);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_192' ),
         'doc_printer', 'Packing Doc Prn 141' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_192' ),
         'lab_printer', 'Packing Lab Prn 192' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_193');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_193',
         193);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_193',
         193);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_193',
         193);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_193',
         193);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_193' ),
         'doc_printer', 'Packing Doc Prn 142' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_193' ),
         'lab_printer', 'Packing Lab Prn 193' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_194');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_194',
         194);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_194',
         194);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_194',
         194);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_194',
         194);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_194' ),
         'doc_printer', 'Packing Doc Prn 142' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_194' ),
         'lab_printer', 'Packing Lab Prn 194' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_195');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_195',
         195);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_195',
         195);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_195',
         195);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_195',
         195);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_195' ),
         'doc_printer', 'Packing Doc Prn 143' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_195' ),
         'lab_printer', 'Packing Lab Prn 195' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_196');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_196',
         196);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_196',
         196);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_196',
         196);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_196',
         196);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_196' ),
         'doc_printer', 'Packing Doc Prn 143' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_196' ),
         'lab_printer', 'Packing Lab Prn 196' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_197');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_197',
         197);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_197',
         197);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_197',
         197);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_197',
         197);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_197' ),
         'doc_printer', 'Packing Doc Prn 144' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_197' ),
         'lab_printer', 'Packing Lab Prn 197' );

INSERT INTO system_config.config_group (name) VALUES ('PackingStation_198');

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 2),
         'packing_station',
         'PackingStation_198',
         198);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 4),
         'packing_station',
         'PackingStation_198',
         198);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 6),
         'packing_station',
         'PackingStation_198',
         198);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value, sequence
            )
VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 8),
         'packing_station',
         'PackingStation_198',
         198);

INSERT INTO system_config.config_group_setting (
                config_group_id, setting, value
            )
VALUES ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_198' ),
         'doc_printer', 'Packing Doc Prn 144' ),
       ( ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_198' ),
         'lab_printer', 'Packing Lab Prn 198' );

COMMIT;
