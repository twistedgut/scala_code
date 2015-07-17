-- Shouldn't have added this config entry. It breaks stuff, hence removing...
BEGIN;

DELETE FROM system_config.config_group WHERE name = 'PackingStationList' AND channel_id = 7;

COMMIT;
