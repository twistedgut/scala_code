-- Clean up values that have dc2 in them

BEGIN;

    UPDATE system_config.config_group_setting
        SET value = 'returns-dc3' where value = 'returns-dc2';

    UPDATE system_config.config_group_setting
        SET value = 'returns-bc-large-dc3' where value = 'returns-bc-large-dc2';

    UPDATE system_config.config_group_setting
        SET value = 'returns-bc-small-dc3' where value = 'returns-bc-small-dc2';

    UPDATE system_config.config_group_setting
        SET value = 'returns_dc3_2' where value = 'returns_dc2_2';

    UPDATE system_config.config_group_setting
        SET value = 'shipping-dc3' where value = 'shipping-dc2' AND setting = 'Shipping Document 1';

    UPDATE system_config.config_group_setting
        SET value = 'shipping-dc3' where value = 'shipping-dc2' AND setting = 'Shipping Document 2';

COMMIT;
