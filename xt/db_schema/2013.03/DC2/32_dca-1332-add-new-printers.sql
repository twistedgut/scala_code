BEGIN;

-- Insert printer stations for new Returns In printers

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_Spare_01', null, 't');

INSERT INTO system_config.config_group
(name, channel_id, active)
VALUES
('Printer_Station_Returns_In_Spare_02', null, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_Spare_01',8,'t');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'PrinterStationListReturnsIn'
 AND    channel_id = 2),
'printer_station','Printer_Station_Returns_In_Spare_02',9,'t');

-- Insert printers for those new printer stations
INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_Spare_01'),
'printer', 'returns_dc2_spare_1', 8, 't');

INSERT INTO system_config.config_group_setting
(config_group_id, setting, value, sequence, active)
VALUES (
(SELECT id
 FROM   system_config.config_group
 WHERE  name = 'Printer_Station_Returns_In_Spare_02'),
'printer', 'returns_dc2_spare_2', 9, 't');

COMMIT;
