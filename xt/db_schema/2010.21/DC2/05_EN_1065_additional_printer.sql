BEGIN;

INSERT INTO system_config.config_group
(name,active)
VALUES
('Printer_Station_Returns_In_02','true');

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,sequence,active)
VALUES
( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = '2' ), 'printer_station', 'Printer_Station_Returns_In_02', '2', 'true' );

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,sequence,active)
VALUES
( (SELECT id FROM system_config.config_group WHERE name = 'PrinterStationListReturnsIn' AND channel_id = '4' ), 'printer_station', 'Printer_Station_Returns_In_02', '2', 'true' );

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,sequence,active)
VALUES
( (SELECT id FROM system_config.config_group WHERE name = 'Printer_Station_Returns_In_02' ), 'printer', 'returns_dc2_2', '1', 'true' );


COMMIT;
