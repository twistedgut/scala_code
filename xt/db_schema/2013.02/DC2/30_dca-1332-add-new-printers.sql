BEGIN;

-- Insert printer stations for new Returns In printers

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_03', null, 't');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_04', null, 't');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_05', null, 't');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_06', null, 't');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_07', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_03',3,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_04',4,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_05',5,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
 'printer_station','Printer_Station_Returns_In_06',6,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_07',7,'t');

-- Insert printers for those new printer stations
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_03'),
'printer', 'returns_dc2_3', 2, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_04'),
'printer', 'returns_dc2_4', 3, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_05'),
'printer', 'returns_dc2_5', 4, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_06'),
'printer', 'returns_dc2_6', 5, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_07'),
'printer', 'returns_dc2_7', 6, 't');

COMMIT;
