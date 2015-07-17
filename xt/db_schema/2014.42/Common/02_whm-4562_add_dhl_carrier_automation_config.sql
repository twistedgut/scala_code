-- Add new system parameters for DHL carrier automation configuration

BEGIN WORK;

-- Create DHL carrier automation group
INSERT INTO system_config.parameter_group (name,description,visible)
  VALUES ('dhl_carrier_automation', 'DHL carrier automation', TRUE);

-- Create auto-selection options
INSERT INTO system_config.parameter
  (parameter_group_id, parameter_type_id, name, description, value, sort_order)
  VALUES
  (
    (SELECT id FROM system_config.parameter_group WHERE name = 'dhl_carrier_automation'),
    (SELECT id FROM system_config.parameter_type WHERE type = 'boolean'),
    'is_dhl_automated',
    'Enable DHL Carrier Automation',
    '0',
    6000
  );

COMMIT;
