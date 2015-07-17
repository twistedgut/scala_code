-- Add premier packing printers 5-8 for DC3

BEGIN;

DO $$
DECLARE
    packing_station_list_id INT;
    premier_station_name TEXT;
    station_id INT;
    printer_settings TEXT[] := ARRAY[['doc_printer','doc'],['card_printer','crd']];
    printer_id INT;
BEGIN

    SELECT id INTO packing_station_list_id
        FROM system_config.config_group
        WHERE name = 'PackingStationList'
        AND channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' );

    FOR station_count IN 5..8 LOOP
        premier_station_name := ( 'PremierStation_' || lpad(station_count::text, 2, '0') );

        INSERT INTO system_config.config_group_setting
            ( config_group_id, setting, value, sequence )
        VALUES (
            packing_station_list_id,
            'packing_station',
            premier_station_name,
            ( SELECT MAX(id) FROM system_config.config_group_setting WHERE config_group_id = packing_station_list_id )
        );

        INSERT INTO system_config.config_group (name) VALUES (premier_station_name)
            RETURNING id INTO station_id;

        -- Do our station/physical printer mappings
        CASE station_count
            WHEN 5,6 THEN printer_id := 3;
            WHEN 7,8 THEN printer_id := 4;
        END CASE;

        FOR i IN array_lower(printer_settings,1) .. array_upper(printer_settings,1) LOOP
            INSERT INTO system_config.config_group_setting
                ( config_group_id, setting, value )
                VALUES (
                    station_id,
                    printer_settings[i][1],                                     -- doc_printer/card_printer
                    'hkp_' || printer_settings[i][2] || '_' || printer_id::text -- hkp_{doc,crd}_{3,4}
                );
            RAISE INFO 'Added % for premier station %', printer_settings[i][1], station_count;
        END LOOP;
    END LOOP;
END$$;

COMMIT;
