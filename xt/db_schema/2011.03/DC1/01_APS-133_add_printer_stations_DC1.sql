-- APS-133: Add new Printer Stations for Returns In and Returns QC for DC1 only

BEGIN WORK;

--
-- Add New Printers
--

-- Add Returns In - Group
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_05');
-- Add Returns In - Setting
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_05'
    ),
    'printer',
    'returns_in_printer_05'
)
;

-- Add Returns QC - Group
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_05');
-- Add Returns QC - Settings
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_05'
    ),
    'printer_large',
    'returns_qc_printer_large_05',
    1
)
;
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_05'
    ),
    'printer_small',
    'returns_qc_printer_small_05',
    2
)
;


--
-- Assign Printers to Print Station Lists
--

-- Returns In 05
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_05',
        5
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id
;

-- Returns QC 05
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_05',
        5
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id
;

COMMIT WORK;
