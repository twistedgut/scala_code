-- DCS-1361: Populate the system_config tables with Packing Stations that should actually exist in DC2
--           for DC2 Carrier Automation.

BEGIN WORK;

--
-- First get rid of the test ones that
-- were put there as a temporary measure
--

-- Clear out the system_config.config_group_setting
DELETE  FROM system_config.config_group_setting
WHERE   config_group_id IN (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'PackingStationList'
        OR      name LIKE 'PackingStation_%'
    )
;
-- Clear out the system_config.config_group
DELETE  FROM system_config.config_group
WHERE   name = 'PackingStationList'
OR      name LIKE 'PackingStation_%'
;

--
-- Second Create the New Packing Stations
--

-- Create the Packing Station Groups
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_01' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_02' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_03' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_04' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_05' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_06' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_07' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_08' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_09' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_10' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_11' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_12' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_13' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_14' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_15' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_16' );
-- Create the Packing Station Settings for the above Groups assigning a Document & Label printer to each
-- PS 01
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_01'), 'doc_printer', 'Packing Doc Prn 01' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_01'), 'lab_printer', 'Packing Lab Prn 01' );
-- PS 02
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_02'), 'doc_printer', 'Packing Doc Prn 01' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_02'), 'lab_printer', 'Packing Lab Prn 02' );
-- PS 03
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_03'), 'doc_printer', 'Packing Doc Prn 01' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_03'), 'lab_printer', 'Packing Lab Prn 03' );
-- PS 04
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_04'), 'doc_printer', 'Packing Doc Prn 01' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_04'), 'lab_printer', 'Packing Lab Prn 04' );
-- PS 05
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_05'), 'doc_printer', 'Packing Doc Prn 02' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_05'), 'lab_printer', 'Packing Lab Prn 05' );
-- PS 06
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_06'), 'doc_printer', 'Packing Doc Prn 02' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_06'), 'lab_printer', 'Packing Lab Prn 06' );
-- PS 07
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_07'), 'doc_printer', 'Packing Doc Prn 02' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_07'), 'lab_printer', 'Packing Lab Prn 07' );
-- PS 08
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_08'), 'doc_printer', 'Packing Doc Prn 02' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_08'), 'lab_printer', 'Packing Lab Prn 08' );
-- PS 09
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_09'), 'doc_printer', 'Packing Doc Prn 03' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_09'), 'lab_printer', 'Packing Lab Prn 09' );
-- PS 10
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_10'), 'doc_printer', 'Packing Doc Prn 03' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_10'), 'lab_printer', 'Packing Lab Prn 10' );
-- PS 11
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_11'), 'doc_printer', 'Packing Doc Prn 03' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_11'), 'lab_printer', 'Packing Lab Prn 11' );
-- PS 12
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_12'), 'doc_printer', 'Packing Doc Prn 03' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_12'), 'lab_printer', 'Packing Lab Prn 12' );
-- PS 13
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_13'), 'doc_printer', 'Packing Doc Prn 04' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_13'), 'lab_printer', 'Packing Lab Prn 13' );
-- PS 14
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_14'), 'doc_printer', 'Packing Doc Prn 04' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_14'), 'lab_printer', 'Packing Lab Prn 14' );
-- PS 15
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_15'), 'doc_printer', 'Packing Doc Prn 04' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_15'), 'lab_printer', 'Packing Lab Prn 15' );
-- PS 16
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_16'), 'doc_printer', 'Packing Doc Prn 04' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_16'), 'lab_printer', 'Packing Lab Prn 16' );

--
-- Third Create the list of Packing Stations per Sales Channel
--

-- Create the Packing Station List groups per Sales Channel
INSERT INTO system_config.config_group (name,channel_id) VALUES (
    'PackingStationList',
    (SELECT c.id
     FROM   channel c
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'NAP'
    )
)
;
INSERT INTO system_config.config_group (name,channel_id) VALUES (
    'PackingStationList',
    (SELECT c.id
     FROM   channel c
            JOIN business b ON b.id = c.business_id
                            AND b.config_section = 'OUTNET'
    )
)
;
-- Associate the Packing Stations with the appropriate Sales Channel Packing Station List
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  (SELECT g.id
         FROM   system_config.config_group g
                JOIN channel c ON c.id = g.channel_id
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'NAP'
         WHERE  g.name = 'PackingStationList'
        ),
        'packing_station',
        name,
        CAST(REPLACE(name,'PackingStation_','') AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'PackingStation_(01|02|03|04|05|06|07|08|09|10|11|12)'
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  (SELECT g.id
         FROM   system_config.config_group g
                JOIN channel c ON c.id = g.channel_id
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'OUTNET'
         WHERE  g.name = 'PackingStationList'
        ),
        'packing_station',
        name,
        CAST(REPLACE(name,'PackingStation_','') AS INTEGER) - 12
FROM    system_config.config_group
WHERE   name ~ 'PackingStation_(13|14|15|16)'
;

COMMIT WORK;
