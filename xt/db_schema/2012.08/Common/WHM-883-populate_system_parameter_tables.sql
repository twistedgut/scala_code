-- WHM-883 Populate system parameters for auto-selection.

BEGIN WORK;

    -- Create Fulfilment/Selection group
    -- (XT will split on slashes to fake a two-level hierarchy.
    INSERT INTO system_config.parameter_group (name,description,visible)
        VALUES ('fulfilment/selection', 'Fulfilment/Selection', TRUE);

    -- Create auto-selection options
    INSERT INTO system_config.parameter
        (parameter_group_id, parameter_type_id, name, description, value)
        VALUES
        (
            (SELECT id FROM system_config.parameter_group WHERE name = 'fulfilment/selection'),
            (SELECT id FROM system_config.parameter_type WHERE type = 'boolean'),
            'enable_auto_selection',
            'Enable Auto-Selection',
            '0'
        ),
        (
            (SELECT id FROM system_config.parameter_group WHERE name = 'fulfilment/selection'),
            (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
            'batch_size',
            'Batch Size',
            '20'
        ),
        (
            (SELECT id FROM system_config.parameter_group WHERE name = 'fulfilment/selection'),
            (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
            'batch_interval',
            'Batch Interval (Minutes)',
            '1'
        );

COMMIT;
