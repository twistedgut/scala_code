BEGIN;

insert into system_config.parameter_type(
    type
) values (
    'nullable_datetime_with_timezone'
);

insert into system_config.parameter (
    parameter_group_id,
    parameter_type_id,
    name,
    description,
    value,
    sort_order
) values (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='nullable_datetime_with_timezone'),
    'exclude_sample_shipments_after',
    'Exclude Sample Shipments after (Datetime)',
    '',
    6001
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='nullable_datetime_with_timezone'),
    'exclude_premier_shipments_after',
    'Exclude Premier Shipments after (Datetime)',
    '',
    6002
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='nullable_datetime_with_timezone'),
    'exclude_standard_shipments_after',
    'Exclude Standard Shipments after (Datetime)',
    '',
    6003
);

COMMIT;
