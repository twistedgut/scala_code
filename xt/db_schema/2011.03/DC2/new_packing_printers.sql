--  Create new packing station printers

BEGIN WORK;

--
-- Create the New Packing Stations
--

-- Create the Packing Station Groups
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_25' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_26' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_27' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_28' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_29' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_30' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_31' );
INSERT INTO system_config.config_group (name) VALUES ( 'PackingStation_32' );
-- Create the Packing Station Settings for the above Groups assigning a Document & Label printer to each
-- PS 25
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_25'), 'doc_printer', 'Packing Doc Prn 07' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_25'), 'lab_printer', 'Packing Lab Prn 25' );
-- PS 26
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_26'), 'doc_printer', 'Packing Doc Prn 07' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_26'), 'lab_printer', 'Packing Lab Prn 26' );
-- PS 27
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_27'), 'doc_printer', 'Packing Doc Prn 07' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_27'), 'lab_printer', 'Packing Lab Prn 27' );
-- PS 28
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_28'), 'doc_printer', 'Packing Doc Prn 07' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_28'), 'lab_printer', 'Packing Lab Prn 28' );
-- PS 29
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_29'), 'doc_printer', 'Packing Doc Prn 08' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_29'), 'lab_printer', 'Packing Lab Prn 29' );
-- PS 30
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_30'), 'doc_printer', 'Packing Doc Prn 08' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_30'), 'lab_printer', 'Packing Lab Prn 30' );
-- PS 31
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_31'), 'doc_printer', 'Packing Doc Prn 08' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_31'), 'lab_printer', 'Packing Lab Prn 31' );
-- PS 32
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_32'), 'doc_printer', 'Packing Doc Prn 08' );
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_32'), 'lab_printer', 'Packing Lab Prn 32' );

--
-- Third Create the list of Packing Stations per Sales Channel
--

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
WHERE   name ~ 'PackingStation_(25|26|27|28|29|30|31|32)'
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
        CAST(REPLACE(name,'PackingStation_','') AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'PackingStation_(25|26|27|28|29|30|31|32)'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  (SELECT g.id
         FROM   system_config.config_group g
                JOIN channel c ON c.id = g.channel_id
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'MRP'
         WHERE  g.name = 'PackingStationList'
        ),
        'packing_station',
        name,
        CAST(REPLACE(name,'PackingStation_','') AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'PackingStation_(25|26|27|28|29|30|31|32)'
;

COMMIT WORK;

