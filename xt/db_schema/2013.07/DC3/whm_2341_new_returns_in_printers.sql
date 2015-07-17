BEGIN;

-- Add new Returns(IN) stations
INSERT INTO system_config.config_group (name) VALUES
    ('Printer_Station_Customer_Returns_In_05'),
    ('Printer_Station_Customer_Returns_In_06'),
    ('Printer_Station_Customer_Returns_In_07'),
    ('Printer_Station_Customer_Returns_In_08'),
    ('Printer_Station_Customer_Returns_In_09'),
    ('Printer_Station_Customer_Returns_In_10'),
    ('Printer_Station_Customer_Returns_In_11'),
    ('Printer_Station_Customer_Returns_In_12'),
    ('Printer_Station_Customer_Returns_In_13'),
    ('Printer_Station_Customer_Returns_In_14'),
    ('Printer_Station_Customer_Returns_In_15'),
    ('Printer_Station_Customer_Returns_In_16')
;

-- Add them all to PrinterStationListReturnsQC (for each channel)
INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_05', 6),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_05', 6),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_05', 6),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_06', 7),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_06', 7),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_06', 7),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_07', 8),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_07', 8),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_07', 8),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_08', 9),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_08', 9),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_08', 9),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_16', 17),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_In_16', 17),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_In_16', 17)
;

-- The way that the document printers are currently assigned isn't quite how they want it.
-- So we'll fix it whilst also assigning printers to our new stations
DELETE FROM system_config.config_group_setting WHERE value like 'crs_doc_%';
INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_01'), 'printer', 'crs_doc_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_02'), 'printer', 'crs_doc_1' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_03'), 'printer', 'crs_doc_2' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_04'), 'printer', 'crs_doc_2' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_05'), 'printer', 'crs_doc_3' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_06'), 'printer', 'crs_doc_3' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_07'), 'printer', 'crs_doc_4' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_08'), 'printer', 'crs_doc_4' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_09'), 'printer', 'crs_doc_5' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_10'), 'printer', 'crs_doc_5' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_11'), 'printer', 'crs_doc_6' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_12'), 'printer', 'crs_doc_6' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_13'), 'printer', 'crs_doc_7' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_14'), 'printer', 'crs_doc_7' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_15'), 'printer', 'crs_doc_8' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_In_16'), 'printer', 'crs_doc_8' )
;

COMMIT;
