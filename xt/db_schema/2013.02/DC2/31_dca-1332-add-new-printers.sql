BEGIN;

-- Insert printer stations for new Returns QC printers

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_09', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_09',9,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_09',9,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_09',9,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_09',9,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_10', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_10',10,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_10',10,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_10',10,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_10',10,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_11', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_11',11,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_11',11,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_11',11,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_11',11,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_12', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_12',12,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_12',12,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_12',12,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_12',12,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_13', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_13',13,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_13',13,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_13',13,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_13',13,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_14', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_14',14,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_14',14,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_14',14,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_14',14,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_15', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_15',15,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_15',15,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_15',15,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_15',15,'t');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_QC_16', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_QC_16',16,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 4),
'printer_station','Printer_Station_Returns_QC_16',16,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 6),
'printer_station','Printer_Station_Returns_QC_16',16,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsQC'
 AND    channel_id = 8),
'printer_station','Printer_Station_Returns_QC_16',16,'t');

-- Insert printers for those new printer stations
-- (one large and one small for each station, apparently)
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_09'),
'printer_large', 'returns_qc_large_09', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_09'),
'printer_small', 'returns_qc_small_09', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_10'),
'printer_large', 'returns_qc_large_10', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_10'),
'printer_small', 'returns_qc_small_10', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_11'),
'printer_large', 'returns_qc_large_11', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_11'),
'printer_small', 'returns_qc_small_11', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_12'),
'printer_large', 'returns_qc_large_12', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_12'),
'printer_small', 'returns_qc_small_12', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_13'),
'printer_large', 'returns_qc_large_13', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_13'),
'printer_small', 'returns_qc_small_13', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_14'),
'printer_large', 'returns_qc_large_14', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_14'),
'printer_small', 'returns_qc_small_14', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_15'),
'printer_large', 'returns_qc_large_15', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_15'),
'printer_small', 'returns_qc_small_15', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_16'),
'printer_large', 'returns_qc_large_16', 1, 't');
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_QC_16'),
'printer_small', 'returns_qc_small_16', 2, 't');

COMMIT;
