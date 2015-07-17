BEGIN;

INSERT INTO system_config.parameter_group(name,description,visible)
 VALUES ('webconsistency','Web Stock Consistency check',true);

INSERT INTO system_config.parameter(parameter_group_id,parameter_type_id,name,description,value,sort_order)
 VALUES (
   (SELECT id FROM system_config.parameter_group WHERE name='webconsistency'),
   (SELECT id FROM system_config.parameter_type WHERE type='integer-set'),
   'pids',
   'PIDs to exclude from the check (comma-separated list)',
   '',
   1000
);

COMMIT;
