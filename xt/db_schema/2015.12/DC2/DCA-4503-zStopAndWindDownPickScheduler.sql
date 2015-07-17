BEGIN;

insert into system_config.parameter_group (name,description,visible) values ('wind_down_pick_scheduler', 'Wind Down Pick Scheduler', 'f');

update system_config.parameter
set parameter_group_id = (select id from system_config.parameter_group where name='wind_down_pick_scheduler')
where name in (
    'exclude_sample_shipments_after',
    'exclude_premier_shipments_after',
    'exclude_standard_shipments_after'
);

COMMIT;
