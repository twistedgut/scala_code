-- Remove all Returns In printers from all DCs as they where moved to the new printer system

BEGIN;

DELETE
FROM system_config.config_group_setting
WHERE config_group_id IN (
    SELECT id
    FROM system_config.config_group
    WHERE name ILIKE '%returns_in%'
);

SELECT id
FROM system_config.config_group
WHERE name ILIKE '%returns_in%';

COMMIT;
