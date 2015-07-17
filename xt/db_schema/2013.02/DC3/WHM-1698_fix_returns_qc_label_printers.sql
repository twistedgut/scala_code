-- Change names of printers in config group table for Returns QC label printers in station 01

BEGIN;

    UPDATE system_config.config_group_setting
        SET value = 'returns_qc_large_01'
        WHERE value='returns-bc-large-dc3';

    UPDATE system_config.config_group_setting
        SET value = 'returns_qc_small_01'
        WHERE value='returns-bc-small-dc3';

COMMIT;
