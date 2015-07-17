BEGIN;

CREATE OR REPLACE FUNCTION mrp_printers()
RETURNS VOID AS $$
DECLARE
    printer_group_id INTEGER;

BEGIN
    -- Store the printer group id
    SELECT id INTO printer_group_id FROM system_config.config_group WHERE name = 'PackingPrinterList';

    -- Delete existing mrp printers
    DELETE FROM system_config.config_group_setting WHERE config_group_id = printer_group_id AND setting ILIKE 'mrp printer%';

    -- Set the sequence
    PERFORM setval('system_config.config_group_setting_id_seq', (SELECT MAX(id) FROM system_config.config_group_setting));

    -- Insert new mrp printer rows
    INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence, active) VALUES
        ( printer_group_id, 'MRP Printer 1', 'MRP-PACKPRN01-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 2', 'MRP-PACKPRN02-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 3', 'MRP-PACKPRN03-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 4', 'MRP-PACKPRN04-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 5', 'MRP-PACKPRN05-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 6', 'MRP-PACKPRN06-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 7', 'MRP-PACKPRN07-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 8', 'MRP-PACKPRN08-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 9', 'MRP-PACKPRN09-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 10', 'MRP-PACKPRN10-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 11', 'MRP-PACKPRN11-XT-DC2', 0, true ),
        ( printer_group_id, 'MRP Printer 12', 'MRP-PACKPRN12-XT-DC2', 0, true )
    ;
END;
$$ LANGUAGE plpgsql;

SELECT mrp_printers();
DROP FUNCTION mrp_printers();

COMMIT;
