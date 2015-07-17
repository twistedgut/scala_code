BEGIN;

-- returns qc 17 and 18

INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_17');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'Printer_Station_Returns_QC_17', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsQC')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsQC';


INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_large', 'returns_qc_printer_large_17', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_QC_17')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_QC_17';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_small', 'returns_qc_printer_small_17', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_QC_17')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_QC_17';

INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_18');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'Printer_Station_Returns_QC_18', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsQC')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsQC';


INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_large', 'returns_qc_printer_large_18', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_QC_18')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_QC_18';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_small', 'returns_qc_printer_small_18', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_QC_18')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_QC_18';

-- returns in 17 and 18

INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_17');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'Printer_Station_Returns_In_17', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsIn')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsIn';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer', 'returns_in_printer_17', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_In_17')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_In_17';

INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_18');

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer_station', 'Printer_Station_Returns_In_18', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PrinterStationListReturnsIn')
)
FROM system_config.config_group
WHERE name = 'PrinterStationListReturnsIn';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'printer', 'returns_in_printer_18', (
    select coalesce(max(sequence)+1,0)
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='Printer_Station_Returns_In_18')
)
FROM system_config.config_group
WHERE name = 'Printer_Station_Returns_In_18';


COMMIT;
