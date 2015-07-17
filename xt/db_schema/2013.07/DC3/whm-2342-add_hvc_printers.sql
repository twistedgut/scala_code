-- Add HVC printers
-- It's actually ridiculous to have to write this amount of SQL in order to add a printer :(
-- NOTE: We don't have any other JC returns in/qc printers, so not adding an entry for them

BEGIN;

CREATE OR REPLACE FUNCTION whm2342()
RETURNS VOID AS $$
DECLARE
    config_group_printer_id INTEGER;
    hvc_returns_in_station TEXT := 'Printer_Station_HVC_Returns';
    hvc_returns_qc_station TEXT := 'Returns Station HVC';

BEGIN
    -- Get the new returns in station to appear on the selection page
    -- Note that the sequence is '18' as this ticket is done in parallel with
    -- WHM-2341
    INSERT INTO system_config.config_group_setting
        ( config_group_id, setting, value, sequence, active )
    VALUES
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = ( SELECT id FROM channel where name = 'NET-A-PORTER.COM' ) ),
            'printer_station',
            hvc_returns_in_station,
            18,
            true
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = ( SELECT id FROM channel where name = 'theOutnet.com' ) ),
            'printer_station',
            hvc_returns_in_station,
            18,
            true
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = ( SELECT id FROM channel where name = 'MRPORTER.COM' ) ),
            'printer_station',
            hvc_returns_in_station,
            18,
            true
        )
    ;

    -- Map the HVC printer to its station
    INSERT INTO system_config.config_group ( name, active ) VALUES ( hvc_returns_in_station, true ) RETURNING id INTO config_group_printer_id;
    INSERT INTO system_config.config_group_setting
        ( config_group_id, setting, value, sequence, active )
    VALUES
        ( config_group_printer_id, 'printer', 'hvc_doc_1', 1, true )
    ;

    -- Get the new returns qc station to appear on the selection page
    -- Note that the sequence is '18' as this ticket is done in parallel with
    -- WHM-2341
    INSERT INTO system_config.config_group_setting
        ( config_group_id, setting, value, sequence, active )
    VALUES
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = ( SELECT id FROM channel where name = 'NET-A-PORTER.COM' ) ),
            'printer_station',
            hvc_returns_qc_station,
            18,
            true
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = ( SELECT id FROM channel where name = 'theOutnet.com' ) ),
            'printer_station',
            hvc_returns_qc_station,
            18,
            true
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = ( SELECT id FROM channel where name = 'MRPORTER.COM' ) ),
            'printer_station',
            hvc_returns_qc_station,
            18,
            true
        )
    ;

    -- Map the HVC printers to their station
    INSERT INTO system_config.config_group ( name, active ) VALUES ( hvc_returns_qc_station, true ) RETURNING id INTO config_group_printer_id;
    INSERT INTO system_config.config_group_setting
        ( config_group_id, setting, value, sequence, active )
    VALUES
        ( config_group_printer_id, 'printer', 'hvc_large_01', 1, true ),
        ( config_group_printer_id, 'printer', 'hvc_small_01', 2, true )
    ;

END;
$$ LANGUAGE plpgsql;

SELECT whm2342();
DROP FUNCTION whm2342();

COMMIT;
