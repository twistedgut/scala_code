BEGIN;

-- returns qc

INSERT INTO system_config.config_group (name) VALUES ('JC_Printer_Station_Returns_QC');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'JC_Printer_Station_Returns_QC', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsQC')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsQC';


INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_large', 'jc_returns_qc_printer_large_01', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='JC_Printer_Station_Returns_QC')
)
FROM system_config.config_group
WHERE name = 'JC_Printer_Station_Returns_QC';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_small', 'jc_returns_qc_printer_small_01', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='JC_Printer_Station_Returns_QC')
)
FROM system_config.config_group
WHERE name = 'JC_Printer_Station_Returns_QC';

-- returns in

INSERT INTO system_config.config_group (name) VALUES ('JC_Printer_Station_Returns_In');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'JC_Printer_Station_Returns_In', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsIn')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsIn';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer', 'jc_returns_in_printer_01', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='JC_Printer_Station_Returns_In')
)
FROM system_config.config_group
WHERE name = 'JC_Printer_Station_Returns_In';


COMMIT;
