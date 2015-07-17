-- Populates the system_config tables with new groups for Packing Stations and List of Packing Stations

BEGIN WORK;

-- Packing Stations
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_1' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_2' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_3' );

-- Packing Station 1
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_1'),
'doc_printer',
'Packing Doc Printer 1'
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_1'),
'lab_printer',
'Packing Label Printer 1'
);

-- Packing Station 2
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_2'),
'doc_printer',
'Packing Doc Printer 2'
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_2'),
'lab_printer',
'Packing Label Printer 2'
);

-- Packing Station 3
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_3'),
'doc_printer',
'Packing Doc Printer 3'
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
(SELECT id FROM system_config.config_group WHERE name = 'PackingStation_3'),
'lab_printer',
'Packing Label Printer 3'
);

-- Packing Station List
INSERT INTO system_config.config_group (name,channel_id) VALUES (
'PackingStationList',
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP')
);
INSERT INTO system_config.config_group (name,channel_id) VALUES (
'PackingStationList',
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET')
);

-- NAP Packing Station List
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_1',
1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_2',
2
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_3',
3
);

-- OUTNET Packing Station List
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_1',
1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_2',
2
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
(   SELECT  cg.id
    FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET'
    WHERE   cg.name = 'PackingStationList'
),
'packing_station',
'PackingStation_3',
3
);

COMMIT WORK;
