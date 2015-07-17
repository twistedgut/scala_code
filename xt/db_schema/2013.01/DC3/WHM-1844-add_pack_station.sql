BEGIN;

    -- Add more print stations
    DROP FUNCTION IF EXISTS add_print_stations();
    CREATE FUNCTION add_print_stations() RETURNS text as E'
        DECLARE
        cgid INTEGER;
        ret text := '''';
        BEGIN
            FOR number in 21 .. 44 LOOP

                -- insert packing stations
                insert into  system_config.config_group_setting
                    (config_group_id, setting, value, sequence)
                    values
                        ((SELECT id from system_config.config_group where name = ''PackingStationList'' and channel_id = 9), ''packing_station'', ''PackingStation_'' || number, number),
                        ((SELECT id from system_config.config_group where name = ''PackingStationList'' and channel_id = 10), ''packing_station'', ''PackingStation_'' || number, number),
                        ((SELECT id from system_config.config_group where name = ''PackingStationList'' and channel_id = 11), ''packing_station'', ''PackingStation_'' || number, number),
                        ((SELECT id from system_config.config_group where name = ''PackingStationList'' and channel_id = 12), ''packing_station'', ''PackingStation_'' || number, number)
                ;
                

                -- insert packing station config groups
                insert into system_config.config_group (name) values (''PackingStation_'' || number);
                SELECT INTO cgid id from system_config.config_group where name = ''PackingStation_'' || number;

                -- insert packing station printers
                insert into  system_config.config_group_setting
                    (config_group_id, setting, value)
                    values
                        (cgid, ''lab_printer'', ''Packing Lab Prn '' || number),
                        (cgid, ''doc_printer'', ''Packing Doc Prn '' || (number+1)/2)
                ;
                ret = ret || ''Added print station '' || number || ''\n'';
            END LOOP;

            return ret;
        END;
    ' LANGUAGE 'plpgsql';
    select add_print_stations();
    DROP FUNCTION add_print_stations();
    

    -- Drop all existing mrP printers
    DELETE FROM system_config.config_group_setting where config_group_id = (select id from system_config.config_group where name='PackingPrinterList');

    -- create enough MrP Printer to have one for each pack station.
    -- no, we don't have MrP in DC3 yet, but might as well be ready.
    DROP FUNCTION IF EXISTS add_mrp_pack_printers();
    CREATE FUNCTION add_mrp_pack_printers() RETURNS text as E'
        DECLARE
        cgid INTEGER;
        ret text := '''';
        BEGIN

            SELECT INTO cgid id from system_config.config_group where name = ''PackingPrinterList'';

            -- Insert new ones
            FOR number in 1 .. 44 LOOP
                insert into system_config.config_group_setting
                    (config_group_id,setting,value,sequence)
                    VALUES
                    (cgid, ''MRP Printer '' || LPAD(CAST(number as VARCHAR), 3, ''0''), ''mrpsticker_pack_'' || LPAD(CAST(number as VARCHAR), 3, ''0''), number);
                ret = ret || ''Added MRP Printer '' || number || ''\n'';
            END LOOP;

            return ret;
        END;
    ' LANGUAGE 'plpgsql';
    select add_mrp_pack_printers();
    DROP FUNCTION add_mrp_pack_printers();

    
COMMIT;
