BEGIN;

    delete from system_config.config_group where name = 'Blank DB Marker';

COMMIT;
