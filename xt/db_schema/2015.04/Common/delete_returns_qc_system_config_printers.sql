-- Remove all Returns QC printers from all DCs as they where moved to the new printer system

BEGIN;

DELETE
FROM system_config.config_group_setting
WHERE config_group_id IN (
    SELECT id
    FROM system_config.config_group
    WHERE name ILIKE '%Returns_QC%'
    AND name NOT ILIKE '%sample%'
);

DELETE
FROM system_config.config_group
WHERE name ILIKE '%Returns_QC%'
AND name NOT ILIKE '%sample%';

COMMIT;
