-- Enable Auto-Selection

BEGIN WORK;

    -- Set fulfilment/selection/enable_auto_selection=1
    UPDATE system_config.parameter
        SET value='1'
        WHERE parameter_group_id = (
            SELECT id
            FROM system_config.parameter_group
            WHERE name='fulfilment/selection'
        )
        AND name='enable_auto_selection'
        ;

COMMIT;
