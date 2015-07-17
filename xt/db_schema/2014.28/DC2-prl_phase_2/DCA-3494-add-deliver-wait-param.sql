begin;

INSERT INTO system_config.parameter_group(name,description,visible)
 VALUES ('goh','GOH',true);

insert into system_config.parameter (
    parameter_group_id,
    parameter_type_id,
    name,
    description,
    value,
    sort_order
) values (
    (select id from system_config.parameter_group where name='goh'),
    (select id from system_config.parameter_type where type='integer'),
    'deliver_within_seconds',
    'Deliver Wait Time (seconds)',
    300,
    6000
);

commit;
