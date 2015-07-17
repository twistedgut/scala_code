BEGIN;

-- add preferences field
alter table public.operator_preferences add column printer_station_name char(255);

-- add config groups
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_In_01',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_In_02',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_In_03',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_In_04',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_QC_01',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_QC_02',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_QC_03',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_QC_04',  TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsIn', 1, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsIn', 3, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsQC', 1, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsQC', 3, TRUE);

-- add config settings
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=1), 'printer_station', 'Printer_Station_Returns_In_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=1), 'printer_station', 'Printer_Station_Returns_In_02', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=1), 'printer_station', 'Printer_Station_Returns_In_03', 3, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=1), 'printer_station', 'Printer_Station_Returns_In_04', 4, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=3), 'printer_station', 'Printer_Station_Returns_In_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=3), 'printer_station', 'Printer_Station_Returns_In_02', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=3), 'printer_station', 'Printer_Station_Returns_In_03', 3, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=3), 'printer_station', 'Printer_Station_Returns_In_04', 4, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=1), 'printer_station', 'Printer_Station_Returns_QC_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=1), 'printer_station', 'Printer_Station_Returns_QC_02', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=1), 'printer_station', 'Printer_Station_Returns_QC_03', 3, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=1), 'printer_station', 'Printer_Station_Returns_QC_04', 4, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=3), 'printer_station', 'Printer_Station_Returns_QC_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=3), 'printer_station', 'Printer_Station_Returns_QC_02', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=3), 'printer_station', 'Printer_Station_Returns_QC_03', 3, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=3), 'printer_station', 'Printer_Station_Returns_QC_04', 4, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_In_01'), 'printer', 'returns_in_printer_01', 0, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_In_02'), 'printer', 'returns_in_printer_02', 0, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_In_03'), 'printer', 'returns_in_printer_03', 0, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_In_04'), 'printer', 'returns_in_printer_04', 0, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_01'), 'printer_large', 'returns_qc_printer_large_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_01'), 'printer_small', 'returns_qc_printer_small_01', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_02'), 'printer_large', 'returns_qc_printer_large_02', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_02'), 'printer_small', 'returns_qc_printer_small_02', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_03'), 'printer_large', 'returns_qc_printer_large_03', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_03'), 'printer_small', 'returns_qc_printer_small_03', 2, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_04'), 'printer_large', 'returns_qc_printer_large_04', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_04'), 'printer_small', 'returns_qc_printer_small_04', 2, TRUE);

COMMIT;
