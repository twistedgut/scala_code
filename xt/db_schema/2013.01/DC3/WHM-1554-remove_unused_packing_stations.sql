-- Only keep the packing stations we need

BEGIN;
    -- Shouldn't have any users at this stage - but just in case reset their
    -- packing station preferences
    UPDATE operator_preferences SET packing_station_name = NULL, packing_printer = NULL;
    -- Remove packing stations > 20
    DELETE FROM system_config.config_group_setting
        WHERE (SELECT (regexp_matches(value,E'PackingStation_(\\d+)'))[1]::int limit 1) > 20
        OR config_group_id IN (
            SELECT id FROM system_config.config_group WHERE (SELECT (regexp_matches(name,E'PackingStation_(\\d+)'))[1]::int limit 1) > 20
        )
    ;
    DELETE FROM system_config.config_group WHERE (SELECT (regexp_matches(name,E'PackingStation_(\\d+)'))[1]::int limit 1) > 20;

    -- Remove all label printers and replace them with the ones we want
    DELETE FROM system_config.config_group_setting WHERE setting = 'lab_printer';
    INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_01'), 'lab_printer', 'Packing Lab Prn 01' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_02'), 'lab_printer', 'Packing Lab Prn 02' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_03'), 'lab_printer', 'Packing Lab Prn 03' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_04'), 'lab_printer', 'Packing Lab Prn 04' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_05'), 'lab_printer', 'Packing Lab Prn 05' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_06'), 'lab_printer', 'Packing Lab Prn 06' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_07'), 'lab_printer', 'Packing Lab Prn 07' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_08'), 'lab_printer', 'Packing Lab Prn 08' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_09'), 'lab_printer', 'Packing Lab Prn 09' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_10'), 'lab_printer', 'Packing Lab Prn 10' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_11'), 'lab_printer', 'Packing Lab Prn 11' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_12'), 'lab_printer', 'Packing Lab Prn 12' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_13'), 'lab_printer', 'Packing Lab Prn 13' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_14'), 'lab_printer', 'Packing Lab Prn 14' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_15'), 'lab_printer', 'Packing Lab Prn 15' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_16'), 'lab_printer', 'Packing Lab Prn 16' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_17'), 'lab_printer', 'Packing Lab Prn 17' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_18'), 'lab_printer', 'Packing Lab Prn 18' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_19'), 'lab_printer', 'Packing Lab Prn 19' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_20'), 'lab_printer', 'Packing Lab Prn 20' )
    ;

    -- Remove all document printers and replace them with the ones we want
    DELETE FROM system_config.config_group_setting WHERE setting = 'doc_printer';
    INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_01'), 'doc_printer', 'Packing Doc Prn 01' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_02'), 'doc_printer', 'Packing Doc Prn 01' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_03'), 'doc_printer', 'Packing Doc Prn 02' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_04'), 'doc_printer', 'Packing Doc Prn 02' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_05'), 'doc_printer', 'Packing Doc Prn 03' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_06'), 'doc_printer', 'Packing Doc Prn 03' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_07'), 'doc_printer', 'Packing Doc Prn 04' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_08'), 'doc_printer', 'Packing Doc Prn 04' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_09'), 'doc_printer', 'Packing Doc Prn 05' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_10'), 'doc_printer', 'Packing Doc Prn 05' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_11'), 'doc_printer', 'Packing Doc Prn 06' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_12'), 'doc_printer', 'Packing Doc Prn 06' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_13'), 'doc_printer', 'Packing Doc Prn 07' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_14'), 'doc_printer', 'Packing Doc Prn 07' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_15'), 'doc_printer', 'Packing Doc Prn 08' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_16'), 'doc_printer', 'Packing Doc Prn 08' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_17'), 'doc_printer', 'Packing Doc Prn 09' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_18'), 'doc_printer', 'Packing Doc Prn 09' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_19'), 'doc_printer', 'Packing Doc Prn 10' ),
        ( (SELECT id FROM system_config.config_group WHERE name = 'PackingStation_20'), 'doc_printer', 'Packing Doc Prn 10' )
    ;
COMMIT;
