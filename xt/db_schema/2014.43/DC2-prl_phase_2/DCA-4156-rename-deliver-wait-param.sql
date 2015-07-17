BEGIN;

UPDATE system_config.parameter
	SET description = 'Singles Grouping Wait Time'
	WHERE name = 'deliver_within_seconds';

COMMIT;
