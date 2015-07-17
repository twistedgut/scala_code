BEGIN WORK;

--
-- Create the New Packing Stations
--

INSERT INTO system_config.config_group (name,channel_id)
SELECT
    'PackingStationList',
    (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP')
WHERE NOT EXISTS (
    SELECT 1 FROM system_config.config_group
    WHERE  name = 'PackingStationList' AND
        channel_id = (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP')
    );

INSERT INTO system_config.config_group (name,channel_id)
SELECT
    'PackingStationList',
    (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET')
WHERE NOT EXISTS (
    SELECT 1 FROM system_config.config_group
    WHERE  name = 'PackingStationList' AND
        channel_id = (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET')
    );


INSERT INTO system_config.config_group (name,channel_id)
SELECT
    'PackingStationList',
    (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'MRP')
WHERE NOT EXISTS (
    SELECT 1 FROM system_config.config_group
    WHERE  name = 'PackingStationList' AND
        channel_id = (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'MRP')
    );

INSERT INTO system_config.config_group (name,channel_id)
SELECT
    'PackingStationList',
    (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'JC')
WHERE NOT EXISTS (
    SELECT 1 FROM system_config.config_group
    WHERE  name = 'PackingStationList' AND
        channel_id = (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'JC')
    );
-- Create the Packing Station Groups

--UNIT 1
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_01' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_02' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_03' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_04' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_05' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_06' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_07' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_08' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_09' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_10' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_11' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_12' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_13' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_14' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_15' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_16' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_17' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_18' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_19' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_20' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_21' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_22' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_23' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_24' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_25' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_26' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_27' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_28' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_29' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_30' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_31' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_32' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_33' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_34' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_35' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_36' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_37' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_38' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_39' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_40' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_41' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_42' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_43' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_44' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_45' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_46' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_47' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_48' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_49' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_50' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_51' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_52' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_53' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_54' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_55' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_56' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_57' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_58' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_59' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_60' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_61' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_62' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_63' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_64' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_65' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_66' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_67' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_68' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_69' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_70' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_71' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_72' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_73' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_74' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_75' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_76' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_77' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_78' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_79' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_80' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_81' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_82' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_83' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_84' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_85' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_86' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_87' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_88' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_89' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_90' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_91' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_92' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_93' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U1_Packing_Station_94' );

--UNIT 4

INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_01' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_02' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_03' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_04' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_05' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_06' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_07' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_08' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_09' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_10' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_11' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_12' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_13' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_14' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_15' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_16' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_17' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_18' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_19' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_20' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_21' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_22' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_23' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_24' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_25' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_26' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_27' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_U4_Packing_Station_28' );

--JC Printers
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_JC_Packing_Station_01' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_JC_Packing_Station_02' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_JC_Packing_Station_03' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_JC_Packing_Station_04' );
INSERT INTO system_config.config_group (name) VALUES ( 'CHA_JC_Packing_Station_05' );

-- Create the Packing Station Settings for the above Groups assigning a Document & Label printer to each

--P01
INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
VALUES
--P01
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_01'), 'doc_printer', 'Packing Doc U1 01' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_01'), 'lab_printer', 'Packing Lab U1 01' ),
--P02
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_02'), 'doc_printer', 'Packing Doc U1 02' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_02'), 'lab_printer', 'Packing Lab U1 02' ),
--P03
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_03'), 'doc_printer', 'Packing Doc U1 03' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_03'), 'lab_printer', 'Packing Lab U1 03' ),
--P04
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_04'), 'doc_printer', 'Packing Doc U1 04' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_04'), 'lab_printer', 'Packing Lab U1 04' ),
--P05
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_05'), 'doc_printer', 'Packing Doc U1 05' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_05'), 'lab_printer', 'Packing Lab U1 05' ),
--P06
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_06'), 'doc_printer', 'Packing Doc U1 06' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_06'), 'lab_printer', 'Packing Lab U1 06' ),
--P07
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_07'), 'doc_printer', 'Packing Doc U1 07' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_07'), 'lab_printer', 'Packing Lab U1 07' ),
--P08
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_08'), 'doc_printer', 'Packing Doc U1 08' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_08'), 'lab_printer', 'Packing Lab U1 08' ),
--P09
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_09'), 'doc_printer', 'Packing Doc U1 09' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_09'), 'lab_printer', 'Packing Lab U1 09' ),
--P10
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_10'), 'doc_printer', 'Packing Doc U1 10' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_10'), 'lab_printer', 'Packing Lab U1 10' ),
--P11
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_11'), 'doc_printer', 'Packing Doc U1 11' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_11'), 'lab_printer', 'Packing Lab U1 11' ),
--P12
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_12'), 'doc_printer', 'Packing Doc U1 12' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_12'), 'lab_printer', 'Packing Lab U1 12' ),
--P13
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_13'), 'doc_printer', 'Packing Doc U1 13' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_13'), 'lab_printer', 'Packing Lab U1 13' ),
--P14
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_14'), 'doc_printer', 'Packing Doc U1 14' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_14'), 'lab_printer', 'Packing Lab U1 14' ),
--P15
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_15'), 'doc_printer', 'Packing Doc U1 15' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_15'), 'lab_printer', 'Packing Lab U1 15' ),
--P16
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_16'), 'doc_printer', 'Packing Doc U1 16' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_16'), 'lab_printer', 'Packing Lab U1 16' ),
--P17
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_17'), 'doc_printer', 'Packing Doc U1 17' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_17'), 'lab_printer', 'Packing Lab U1 17' ),
--P18
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_18'), 'doc_printer', 'Packing Doc U1 18' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_18'), 'lab_printer', 'Packing Lab U1 18' ),
--P19
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_19'), 'doc_printer', 'Packing Doc U1 19' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_19'), 'lab_printer', 'Packing Lab U1 19' ),
--P20
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_20'), 'doc_printer', 'Packing Doc U1 20' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_20'), 'lab_printer', 'Packing Lab U1 20' ),
--P21
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_21'), 'doc_printer', 'Packing Doc U1 21' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_21'), 'lab_printer', 'Packing Lab U1 21' ),
--P22
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_22'), 'doc_printer', 'Packing Doc U1 22' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_22'), 'lab_printer', 'Packing Lab U1 22' ),
--P23
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_23'), 'doc_printer', 'Packing Doc U1 23' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_23'), 'lab_printer', 'Packing Lab U1 23' ),
--P24
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_24'), 'doc_printer', 'Packing Doc U1 24' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_24'), 'lab_printer', 'Packing Lab U1 24' ),
--P25
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_25'), 'doc_printer', 'Packing Doc U1 25' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_25'), 'lab_printer', 'Packing Lab U1 25' ),
--P26
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_26'), 'doc_printer', 'Packing Doc U1 26' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_26'), 'lab_printer', 'Packing Lab U1 26' ),
--P27
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_27'), 'doc_printer', 'Packing Doc U1 27' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_27'), 'lab_printer', 'Packing Lab U1 27' ),
--P28
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_28'), 'doc_printer', 'Packing Doc U1 28' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_28'), 'lab_printer', 'Packing Lab U1 28' ),
--P29
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_29'), 'doc_printer', 'Packing Doc U1 29' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_29'), 'lab_printer', 'Packing Lab U1 29' ),
--P30
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_30'), 'doc_printer', 'Packing Doc U1 30' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_30'), 'lab_printer', 'Packing Lab U1 30' ),
--P31
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_31'), 'doc_printer', 'Packing Doc U1 31' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_31'), 'lab_printer', 'Packing Lab U1 31' ),
--P32
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_32'), 'doc_printer', 'Packing Doc U1 32' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_32'), 'lab_printer', 'Packing Lab U1 32' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_33'), 'doc_printer', 'Packing Doc U1 33' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_33'), 'lab_printer', 'Packing Lab U1 33' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_34'), 'doc_printer', 'Packing Doc U1 34' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_34'), 'lab_printer', 'Packing Lab U1 34' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_35'), 'doc_printer', 'Packing Doc U1 35' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_35'), 'lab_printer', 'Packing Lab U1 35' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_36'), 'doc_printer', 'Packing Doc U1 36' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_36'), 'lab_printer', 'Packing Lab U1 36' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_37'), 'doc_printer', 'Packing Doc U1 37' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_37'), 'lab_printer', 'Packing Lab U1 37' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_38'), 'doc_printer', 'Packing Doc U1 38' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_38'), 'lab_printer', 'Packing Lab U1 38' ),
--P33
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_39'), 'doc_printer', 'Packing Doc U1 39' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_39'), 'lab_printer', 'Packing Lab U1 39' ),
--P43
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_40'), 'doc_printer', 'Packing Doc U1 40' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_40'), 'lab_printer', 'Packing Lab U1 40' ),
--P41
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_41'), 'doc_printer', 'Packing Doc U1 41' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_41'), 'lab_printer', 'Packing Lab U1 41' ),
--P42
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_42'), 'doc_printer', 'Packing Doc U1 42' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_42'), 'lab_printer', 'Packing Lab U1 42' ),
--P43
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_43'), 'doc_printer', 'Packing Doc U1 43' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_43'), 'lab_printer', 'Packing Lab U1 43' ),
--P44
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_44'), 'doc_printer', 'Packing Doc U1 44' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_44'), 'lab_printer', 'Packing Lab U1 44' ),
--P45
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_45'), 'doc_printer', 'Packing Doc U1 45' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_45'), 'lab_printer', 'Packing Lab U1 45' ),
--P46
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_46'), 'doc_printer', 'Packing Doc U1 46' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_46'), 'lab_printer', 'Packing Lab U1 46' ),
--P47
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_47'), 'doc_printer', 'Packing Doc U1 47' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_47'), 'lab_printer', 'Packing Lab U1 47' ),
--P48
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_48'), 'doc_printer', 'Packing Doc U1 48' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_48'), 'lab_printer', 'Packing Lab U1 48' ),
--P49
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_49'), 'doc_printer', 'Packing Doc U1 49' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_49'), 'lab_printer', 'Packing Lab U1 49' ),
--P50
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_50'), 'doc_printer', 'Packing Doc U1 50' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_50'), 'lab_printer', 'Packing Lab U1 50' ),
--P51
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_51'), 'doc_printer', 'Packing Doc U1 51' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_51'), 'lab_printer', 'Packing Lab U1 51' ),
--P52
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_52'), 'doc_printer', 'Packing Doc U1 52' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_52'), 'lab_printer', 'Packing Lab U1 52' ),
--P53
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_53'), 'doc_printer', 'Packing Doc U1 53' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_53'), 'lab_printer', 'Packing Lab U1 53' ),
--P54
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_54'), 'doc_printer', 'Packing Doc U1 54' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_54'), 'lab_printer', 'Packing Lab U1 54' ),
--P55
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_55'), 'doc_printer', 'Packing Doc U1 55' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_55'), 'lab_printer', 'Packing Lab U1 55' ),
--P56
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_56'), 'doc_printer', 'Packing Doc U1 56' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_56'), 'lab_printer', 'Packing Lab U1 56' ),
--P57
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_57'), 'doc_printer', 'Packing Doc U1 57' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_57'), 'lab_printer', 'Packing Lab U1 57' ),
--P58
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_58'), 'doc_printer', 'Packing Doc U1 58' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_58'), 'lab_printer', 'Packing Lab U1 58' ),
--P59
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_59'), 'doc_printer', 'Packing Doc U1 59' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_59'), 'lab_printer', 'Packing Lab U1 59' ),
--P60
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_60'), 'doc_printer', 'Packing Doc U1 60' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_60'), 'lab_printer', 'Packing Lab U1 60' ),
--P61
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_61'), 'doc_printer', 'Packing Doc U1 61' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_61'), 'lab_printer', 'Packing Lab U1 61' ),
--P62
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_62'), 'doc_printer', 'Packing Doc U1 62' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_62'), 'lab_printer', 'Packing Lab U1 62' ),
--P63
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_63'), 'doc_printer', 'Packing Doc U1 63' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_63'), 'lab_printer', 'Packing Lab U1 63' ),
--P64
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_64'), 'doc_printer', 'Packing Doc U1 64' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_64'), 'lab_printer', 'Packing Lab U1 64' ),
--P65
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_65'), 'doc_printer', 'Packing Doc U1 65' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_65'), 'lab_printer', 'Packing Lab U1 65' ),
--P66
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_66'), 'doc_printer', 'Packing Doc U1 66' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_66'), 'lab_printer', 'Packing Lab U1 66' ),
--P67
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_67'), 'doc_printer', 'Packing Doc U1 67' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_67'), 'lab_printer', 'Packing Lab U1 67' ),
--P68
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_68'), 'doc_printer', 'Packing Doc U1 68' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_68'), 'lab_printer', 'Packing Lab U1 68' ),
--P69
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_69'), 'doc_printer', 'Packing Doc U1 69' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_69'), 'lab_printer', 'Packing Lab U1 69' ),
--P70
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_70'), 'doc_printer', 'Packing Doc U1 70' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_70'), 'lab_printer', 'Packing Lab U1 70' ),
--P71
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_71'), 'doc_printer', 'Packing Doc U1 71' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_71'), 'lab_printer', 'Packing Lab U1 71' ),
--P72
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_72'), 'doc_printer', 'Packing Doc U1 72' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_72'), 'lab_printer', 'Packing Lab U1 72' ),
--P73
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_73'), 'doc_printer', 'Packing Doc U1 73' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_73'), 'lab_printer', 'Packing Lab U1 73' ),
--P74
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_74'), 'doc_printer', 'Packing Doc U1 74' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_74'), 'lab_printer', 'Packing Lab U1 74' ),
--P75
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_75'), 'doc_printer', 'Packing Doc U1 75' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_75'), 'lab_printer', 'Packing Lab U1 75' ),
--P76
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_76'), 'doc_printer', 'Packing Doc U1 76' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_76'), 'lab_printer', 'Packing Lab U1 76' ),
--P77
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_77'), 'doc_printer', 'Packing Doc U1 77' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_77'), 'lab_printer', 'Packing Lab U1 77' ),
--P78
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_78'), 'doc_printer', 'Packing Doc U1 78' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_78'), 'lab_printer', 'Packing Lab U1 78' ),
--P79
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_79'), 'doc_printer', 'Packing Doc U1 79' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_79'), 'lab_printer', 'Packing Lab U1 79' ),
--P80
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_80'), 'doc_printer', 'Packing Doc U1 80' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_80'), 'lab_printer', 'Packing Lab U1 80' ),
--P81
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_81'), 'doc_printer', 'Packing Doc U1 81' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_81'), 'lab_printer', 'Packing Lab U1 81' ),
--P82
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_82'), 'doc_printer', 'Packing Doc U1 82' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_82'), 'lab_printer', 'Packing Lab U1 82' ),
--P83
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_83'), 'doc_printer', 'Packing Doc U1 83' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_83'), 'lab_printer', 'Packing Lab U1 83' ),
--P84
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_84'), 'doc_printer', 'Packing Doc U1 84' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_84'), 'lab_printer', 'Packing Lab U1 84' ),
--P85
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_85'), 'doc_printer', 'Packing Doc U1 85' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_85'), 'lab_printer', 'Packing Lab U1 85' ),
--P86
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_86'), 'doc_printer', 'Packing Doc U1 86' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_86'), 'lab_printer', 'Packing Lab U1 86' ),
--P87
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_87'), 'doc_printer', 'Packing Doc U1 87' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_87'), 'lab_printer', 'Packing Lab U1 87' ),
--P88
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_88'), 'doc_printer', 'Packing Doc U1 88' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_88'), 'lab_printer', 'Packing Lab U1 88' ),
--P89
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_89'), 'doc_printer', 'Packing Doc U1 89' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_89'), 'lab_printer', 'Packing Lab U1 89' ),
--P90
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_90'), 'doc_printer', 'Packing Doc U1 90' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_90'), 'lab_printer', 'Packing Lab U1 90' ),
--P91
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_91'), 'doc_printer', 'Packing Doc U1 91' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_91'), 'lab_printer', 'Packing Lab U1 91' ),
--P92
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_92'), 'doc_printer', 'Packing Doc U1 92' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_92'), 'lab_printer', 'Packing Lab U1 92' ),
--P93
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_93'), 'doc_printer', 'Packing Doc U1 93' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_93'), 'lab_printer', 'Packing Lab U1 93' ),
--P94
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_94'), 'doc_printer', 'Packing Doc U1 94' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U1_Packing_Station_94'), 'lab_printer', 'Packing Lab U1 94' ),
--UNIT4
--P01
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_01'), 'doc_printer', 'Packing Doc U4 01' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_01'), 'lab_printer', 'Packing Lab U4 01' ),
--P02
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_02'), 'doc_printer', 'Packing Doc U4 02' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_02'), 'lab_printer', 'Packing Lab U4 02' ),
--P03
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_03'), 'doc_printer', 'Packing Doc U4 03' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_03'), 'lab_printer', 'Packing Lab U4 03' ),
--P04
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_04'), 'doc_printer', 'Packing Doc U4 04' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_04'), 'lab_printer', 'Packing Lab U4 04' ),
--P05
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_05'), 'doc_printer', 'Packing Doc U4 05' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_05'), 'lab_printer', 'Packing Lab U4 05' ),
--P06
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_06'), 'doc_printer', 'Packing Doc U4 06' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_06'), 'lab_printer', 'Packing Lab U4 06' ),
--P07
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_07'), 'doc_printer', 'Packing Doc U4 07' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_07'), 'lab_printer', 'Packing Lab U4 07' ),
--P08
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_08'), 'doc_printer', 'Packing Doc U4 08' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_08'), 'lab_printer', 'Packing Lab U4 08' ),
--P09
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_09'), 'doc_printer', 'Packing Doc U4 09' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_09'), 'lab_printer', 'Packing Lab U4 09' ),
--P10
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_10'), 'doc_printer', 'Packing Doc U4 10' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_10'), 'lab_printer', 'Packing Lab U4 10' ),
--P11
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_11'), 'doc_printer', 'Packing Doc U4 11' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_11'), 'lab_printer', 'Packing Lab U4 11' ),
--P12
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_12'), 'doc_printer', 'Packing Doc U4 12' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_12'), 'lab_printer', 'Packing Lab U4 12' ),
--P13
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_13'), 'doc_printer', 'Packing Doc U4 13' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_13'), 'lab_printer', 'Packing Lab U4 13' ),
--P14
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_14'), 'doc_printer', 'Packing Doc U4 14' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_14'), 'lab_printer', 'Packing Lab U4 14' ),
--P15
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_15'), 'doc_printer', 'Packing Doc U4 15' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_15'), 'lab_printer', 'Packing Lab U4 15' ),
--P16
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_16'), 'doc_printer', 'Packing Doc U4 16' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_16'), 'lab_printer', 'Packing Lab U4 16' ),
--P17
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_17'), 'doc_printer', 'Packing Doc U4 17' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_17'), 'lab_printer', 'Packing Lab U4 17' ),
--P18
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_18'), 'doc_printer', 'Packing Doc U4 18' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_18'), 'lab_printer', 'Packing Lab U4 18' ),
--P19
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_19'), 'doc_printer', 'Packing Doc U4 19' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_19'), 'lab_printer', 'Packing Lab U4 19' ),
--P20
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_20'), 'doc_printer', 'Packing Doc U4 20' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_20'), 'lab_printer', 'Packing Lab U4 20' ),
--P21
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_21'), 'doc_printer', 'Packing Doc U4 21' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_21'), 'lab_printer', 'Packing Lab U4 21' ),
--P22
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_22'), 'doc_printer', 'Packing Doc U4 22' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_22'), 'lab_printer', 'Packing Lab U4 22' ),
--P23
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_23'), 'doc_printer', 'Packing Doc U4 23' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_23'), 'lab_printer', 'Packing Lab U4 23' ),
--P24
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_24'), 'doc_printer', 'Packing Doc U4 24' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_24'), 'lab_printer', 'Packing Lab U4 24' ),
--P25
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_25'), 'doc_printer', 'Packing Doc U4 25' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_25'), 'lab_printer', 'Packing Lab U4 25' ),
--P26
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_26'), 'doc_printer', 'Packing Doc U4 26' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_26'), 'lab_printer', 'Packing Lab U4 26' ),
--P27
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_27'), 'doc_printer', 'Packing Doc U4 27' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_27'), 'lab_printer', 'Packing Lab U4 27' ),
--P28
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_28'), 'doc_printer', 'Packing Doc U4 28' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_U4_Packing_Station_28'), 'lab_printer', 'Packing Lab U4 28' ),

--JC Printers
--P01
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_01'), 'doc_printer', 'Packing Doc JC 01' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_01'), 'lab_printer', 'Packing Lab JC 01' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_01'), 'card_printer', 'Packing Address Card JC 01' ),
--P02
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_02'), 'doc_printer', 'Packing Doc JC 02' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_02'), 'lab_printer', 'Packing Lab JC 02' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_02'), 'card_printer', 'Packing Address Card JC 01' ),
--P03
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_03'), 'doc_printer', 'Packing Doc JC 03' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_03'), 'lab_printer', 'Packing Lab JC 03' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_03'), 'card_printer', 'Packing Address Card JC 01' ),
--P04
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_04'), 'doc_printer', 'Packing Doc JC 04' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_04'), 'lab_printer', 'Packing Lab JC 04' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_04'), 'card_printer', 'Packing Address Card JC 01' ),
--P05
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_05'), 'doc_printer', 'Packing Doc JC 05' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_05'), 'lab_printer', 'Packing Lab JC 05' ),
( (SELECT id FROM system_config.config_group WHERE name = 'CHA_JC_Packing_Station_05'), 'card_printer', 'Packing Address Card JC 01' );

--
-- Third Create the list of Packing Stations per Sales Channel
--

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'CHA_U1_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER) + 94
FROM    system_config.config_group
WHERE   name ~ 'CHA_U4_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'CHA_U1_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER) + 94
FROM    system_config.config_group
WHERE   name ~ 'CHA_U4_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'MRP'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER)
FROM    system_config.config_group
WHERE   name ~ 'CHA_U1_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'MRP'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER) + 94
FROM    system_config.config_group
WHERE   name ~ 'CHA_U4_Packing_Station_'
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT (
    SELECT g.id
    FROM system_config.config_group g
    JOIN channel c ON c.id = g.channel_id
    JOIN business b ON b.id = c.business_id AND b.config_section = 'JC'
    WHERE  g.name = 'PackingStationList'
),
'packing_station',
name,
CAST(SPLIT_PART(name,'_',5) AS INTEGER) + 122
FROM    system_config.config_group
WHERE   name ~ 'CHA_JC_Packing_Station_'
;

COMMIT WORK;