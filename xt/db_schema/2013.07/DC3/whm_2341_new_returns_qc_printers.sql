BEGIN;

-- Add new Returns(QC) stations
INSERT INTO system_config.config_group (name) VALUES
    ('Printer_Station_Customer_Returns_QC_09'),
    ('Printer_Station_Customer_Returns_QC_10'),
    ('Printer_Station_Customer_Returns_QC_11'),
    ('Printer_Station_Customer_Returns_QC_12'),
    ('Printer_Station_Customer_Returns_QC_13'),
    ('Printer_Station_Customer_Returns_QC_14'),
    ('Printer_Station_Customer_Returns_QC_15'),
    ('Printer_Station_Customer_Returns_QC_16')
;

-- Add them all to PrinterStationListReturnsQC (for each channel)
INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_09', 10),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_10', 11),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_11', 12),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_12', 13),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_13', 14),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_14', 15),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_15', 16),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_16', 17),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')), 'printer_station', 'Printer_Station_Customer_Returns_QC_16', 17),
    ( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsQC' AND channel_id = (SELECT id from channel where name = 'theOutnet.com')), 'printer_station', 'Printer_Station_Customer_Returns_QC_16', 17)
;

-- Assign a large and small CRS label printers to each
INSERT INTO system_config.config_group_setting (config_group_id, setting, value) VALUES
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_09'), 'printer_large', 'crs_large_09' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_09'), 'printer_small', 'crs_small_09' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_10'), 'printer_large', 'crs_large_10' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_10'), 'printer_small', 'crs_small_10' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_11'), 'printer_large', 'crs_large_11' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_11'), 'printer_small', 'crs_small_11' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_12'), 'printer_large', 'crs_large_12' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_12'), 'printer_small', 'crs_small_12' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_13'), 'printer_large', 'crs_large_13' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_13'), 'printer_small', 'crs_small_13' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_14'), 'printer_large', 'crs_large_14' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_14'), 'printer_small', 'crs_small_14' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_15'), 'printer_large', 'crs_large_15' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_15'), 'printer_small', 'crs_small_15' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_16'), 'printer_large', 'crs_large_16' ),
    ( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Customer_Returns_QC_16'), 'printer_small', 'crs_small_16' )
;

COMMIT;
