BEGIN;

DO $$
BEGIN
    FOR station IN 191..198 LOOP
        INSERT INTO system_config.config_group_setting
            ( config_group_id, setting, value )
        VALUES (
             ( SELECT id FROM system_config.config_group WHERE name = 'PackingStation_' || station ),
            'card_printer',
            'Packing AddressCard Prn ' || station
        );
    END LOOP;
END$$;

COMMIT;
