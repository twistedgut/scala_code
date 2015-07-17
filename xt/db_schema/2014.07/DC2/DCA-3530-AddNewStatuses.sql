begin;

-- rename the old pick scheduler parameters for clarity

update
    system_config.parameter_group
set
    description = 'PRL Pick Scheduler (Version 1)'
where
    name = 'prl';

-- add our new group

insert into system_config.parameter_group (name, description, visible) values (
    'prl_pick_scheduler_v2',
    'PRL Pick Scheduler (Version 2)',
    true
);

-- add our pick scheduler config to the system config table (under our new group)

insert into system_config.parameter (
    parameter_group_id,
    parameter_type_id,
    name,
    description,
    value,
    sort_order
) values (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='integer'),
    'packing_total_capacity',
    'Total Packing Capacity (containers)',
    200,
    1000
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='integer'),
    'full_picking_total_capacity',
    'Total Full PRL Picking Capacity',
    200,
    2000
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='integer'),
    'full_staging_total_capacity',
    'Total Full Staging Capacity',
    300,
    3000
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='integer'),
    'goh_picking_total_capacity',
    'Total GOH Picking Capacity',
    240,
    4000
), (
    (select id from system_config.parameter_group where name='prl_pick_scheduler_v2'),
    (select id from system_config.parameter_type where type='integer'),
    'dcd_picking_total_capacity',
    'Total Dematic DCD Picking Capacity',
    200, -- keep number in line with packing
    5000
);

-- insert our new runtime properties

insert into runtime_property (name, value, description, sort_order) values
    ('packing_remaining_capacity', 0, 'The number of pack spaces that can be reserved', 10),
    ('full_picking_remaining_capacity', 0, 'How many more allocations can still be assigned to the Full PRL', 20),
    ('full_staging_remaining_capacity', 0, 'How much space is available in the Full PRL staging area', 30),
    ('goh_picking_remaining_capacity', 0, 'How many allocations can still be fulfilled by the GOH PRL given its current workload', 40),
    ('dcd_picking_remaining_capacity', 0, 'How many allocations can still be fulfilled by the DCD given its current workload', 50)
;

commit;
