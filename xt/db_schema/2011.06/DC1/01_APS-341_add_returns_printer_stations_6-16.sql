-- APS-341: Add new Printer Stations for Returns In and Returns QC for DC1 only

BEGIN WORK;

--
-- Add New Printers
--

-- Add Returns In - Group
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_06');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_07');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_08');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_09');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_10');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_11');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_12');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_13');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_14');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_15');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_In_16');

-- Add Returns In - Setting
INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_06'
    ),
    'printer',
    'returns_in_printer_06'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_07'
    ),
    'printer',
    'returns_in_printer_07'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_08'
    ),
    'printer',
    'returns_in_printer_08'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_09'
    ),
    'printer',
    'returns_in_printer_09'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_10'
    ),
    'printer',
    'returns_in_printer_10'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_11'
    ),
    'printer',
    'returns_in_printer_11'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_12'
    ),
    'printer',
    'returns_in_printer_12'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_13'
    ),
    'printer',
    'returns_in_printer_13'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_14'
    ),
    'printer',
    'returns_in_printer_14'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_15'
    ),
    'printer',
    'returns_in_printer_15'
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_In_16'
    ),
    'printer',
    'returns_in_printer_16'
);

-- -------------------------

-- Add Returns QC - Group
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_06');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_07');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_08');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_09');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_10');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_11');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_12');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_13');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_14');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_15');
INSERT INTO system_config.config_group (name) VALUES ('Printer_Station_Returns_QC_16');
-- Add Returns QC - Settings
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_06'
    ),
    'printer_large',
    'returns_qc_printer_large_06',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_06'
    ),
    'printer_small',
    'returns_qc_printer_small_06',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_07'
    ),
    'printer_large',
    'returns_qc_printer_large_07',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_07'
    ),
    'printer_small',
    'returns_qc_printer_small_07',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_08'
    ),
    'printer_large',
    'returns_qc_printer_large_08',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_08'
    ),
    'printer_small',
    'returns_qc_printer_small_08',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_09'
    ),
    'printer_large',
    'returns_qc_printer_large_09',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_09'
    ),
    'printer_small',
    'returns_qc_printer_small_09',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_10'
    ),
    'printer_large',
    'returns_qc_printer_large_10',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_10'
    ),
    'printer_small',
    'returns_qc_printer_small_10',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_11'
    ),
    'printer_large',
    'returns_qc_printer_large_11',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_11'
    ),
    'printer_small',
    'returns_qc_printer_small_11',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_12'
    ),
    'printer_large',
    'returns_qc_printer_large_12',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_12'
    ),
    'printer_small',
    'returns_qc_printer_small_12',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_13'
    ),
    'printer_large',
    'returns_qc_printer_large_13',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_13'
    ),
    'printer_small',
    'returns_qc_printer_small_13',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_14'
    ),
    'printer_large',
    'returns_qc_printer_large_14',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_14'
    ),
    'printer_small',
    'returns_qc_printer_small_14',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_15'
    ),
    'printer_large',
    'returns_qc_printer_large_15',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_15'
    ),
    'printer_small',
    'returns_qc_printer_small_15',
    2
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_16'
    ),
    'printer_large',
    'returns_qc_printer_large_16',
    1
);
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'Printer_Station_Returns_QC_16'
    ),
    'printer_small',
    'returns_qc_printer_small_16',
    2
);


--
-- Assign Printers to Print Station Lists
--

-- Returns In 06
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_06',
        6
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 06
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_06',
        6
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 07
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_07',
        7
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 07
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_07',
        7
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 08
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_08',
        8
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 08
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_08',
        8
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 09
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_09',
        9
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 09
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_09',
        9
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 10
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_10',
        10
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 10
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_10',
        10
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 11
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_11',
        11
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 11
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_11',
        11
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 12
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_12',
        12
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 12
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_12',
        12
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 13
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_13',
        13
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 13
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_13',
        13
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 14
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_14',
        14
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 14
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_14',
        14
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 15
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_15',
        15
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 15
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_15',
        15
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

-- Returns In 16
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_In_16',
        16
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsIn'
ORDER BY id;

-- Returns QC 16
INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence)
SELECT  id,
        'printer_station',
        'Printer_Station_Returns_QC_16',
        16
FROM    system_config.config_group
WHERE   name = 'PrinterStationListReturnsQC'
ORDER BY id;

COMMIT WORK;
