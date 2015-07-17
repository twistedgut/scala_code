BEGIN;
-- add preferences field
alter table operator_preferences add column printer_station_name char(255);

-- add config groups
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_In_01',  TRUE);
INSERT INTO system_config.config_group(id, "name",  active)
VALUES ((select max(id) from system_config.config_group)+1, 'Printer_Station_Returns_QC_01',  TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsIn', 2, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsIn', 4, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsQC', 2, TRUE);
INSERT INTO system_config.config_group(id, "name", channel_id, active)
VALUES ((select max(id) from system_config.config_group)+1, 'PrinterStationListReturnsQC', 4, TRUE);

-- add config settings
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=2), 'printer_station', 'Printer_Station_Returns_In_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsIn' and channel_id=4), 'printer_station', 'Printer_Station_Returns_In_01', 1, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=2), 'printer_station', 'Printer_Station_Returns_QC_01', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='PrinterStationListReturnsQC' and channel_id=4), 'printer_station', 'Printer_Station_Returns_QC_01', 1, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_In_01'), 'printer', 'returns-dc2', 0, TRUE);

INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_01'), 'printer_large', 'returns-bc-large-dc2', 1, TRUE);
INSERT INTO system_config.config_group_setting(id, config_group_id, setting, "value", "sequence", active)
VALUES ((select max(id) from system_config.config_group_setting)+1, (select id from system_config.config_group where name='Printer_Station_Returns_QC_01'), 'printer_small', 'returns-bc-small-dc2', 2, TRUE);

COMMIT;
