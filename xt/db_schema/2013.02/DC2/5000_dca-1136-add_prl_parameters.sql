-- Add new system parameters for PRL configuration

BEGIN WORK;

-- Create PRL group
INSERT INTO system_config.parameter_group (name,description,visible)
  VALUES ('prl', 'PRL', TRUE);

-- Create auto-selection options
INSERT INTO system_config.parameter
  (parameter_group_id, parameter_type_id, name, description, value)
  VALUES
  (
    (SELECT id FROM system_config.parameter_group WHERE name = 'prl'),
    (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
    'wall_of_totes_size',
    'Wall of Totes Size',
    '100'
  ),
  (
    (SELECT id FROM system_config.parameter_group WHERE name = 'prl'),
    (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
    'full_prl_pool_size',
    'Full PRL Pool Size',
    '100'
  ),
  (
    (SELECT id FROM system_config.parameter_group WHERE name = 'prl'),
    (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
    'dematic_pool_size',
    'Dematic Pool Size',
    '100'
  ),
  (
    (SELECT id FROM system_config.parameter_group WHERE name = 'prl'),
    (SELECT id FROM system_config.parameter_type WHERE type = 'integer'),
    'packing_pool_size',
    'Packing Pool Size',
    '100'
  );

COMMIT;
