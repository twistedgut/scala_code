-- Add new packing printers for DC1.5

BEGIN;
    -- Add more print stations
    CREATE OR REPLACE FUNCTION add_print_stations()
    RETURNS VOID AS $$
    DECLARE
        cgid INTEGER;
        busid INTEGER;
        maxseq INTEGER;
        numchar VARCHAR;
        psname VARCHAR;

    BEGIN

        SELECT INTO busid g.id FROM system_config.config_group g
            JOIN channel c ON c.id = g.channel_id
            JOIN business b ON b.id = c.business_id
            AND b.config_section = 'OUTNET'
            WHERE g.name = 'PackingStationList';

        SELECT INTO maxseq max(sequence) FROM system_config.config_group_setting where config_group_id = busid;

        FOR number in 1 .. 54 LOOP
            numchar := LPAD(CAST(number as VARCHAR), 2, '0');
            psname := 'RAD_Packing_Station_' || numchar;

             --insert packing stations
            INSERT INTO system_config.config_group (name) VALUES (psname);

            SELECT INTO cgid id FROM system_config.config_group where name = psname;

            INSERT INTO system_config.config_group_setting
                (config_group_id,setting,value)
                VALUES
                    ( cgid, 'lab_printer', 'RAD Packing Lab ' || numchar ),
                    ( cgid, 'doc_printer', 'RAD Packing Doc ' || numchar );

            INSERT INTO system_config.config_group_setting
                (config_group_id,setting,value,sequence)
                VALUES
                    (busid, 'packing_station', psname, number + maxseq);

        END LOOP;
    END;
    $$ LANGUAGE plpgsql;

SELECT add_print_stations();
DROP FUNCTION add_print_stations();

COMMIT;