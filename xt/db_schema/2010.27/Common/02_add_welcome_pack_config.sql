BEGIN;

CREATE OR REPLACE FUNCTION welcome_pack()
RETURNS VOID AS $$
DECLARE
    nap_id INTEGER;
    outnet_id INTEGER;
    mrp_id INTEGER;
    cg_name VARCHAR := 'Welcome_Pack';

BEGIN

    -- Store IDs
    SELECT id INTO nap_id FROM channel WHERE name='NET-A-PORTER.COM';
    SELECT id INTO outnet_id FROM channel WHERE name='theOutnet.com';
    SELECT id INTO mrp_id FROM channel WHERE name='MrPorter.com';

    -- Reset sequences in case they're out of sync
    PERFORM setval('system_config.config_group_id_seq',
        (SELECT max(id) FROM system_config.config_group));

    -- Delete existing Welcome Pack rows
    DELETE FROM system_config.config_group_setting WHERE config_group_id IN
        ( SELECT id FROM system_config.config_group WHERE name = cg_name );
    DELETE FROM system_config.config_group WHERE name = cg_name;

    -- Add new channelised rows
    -- NAP
    INSERT INTO system_config.config_group (
        name, channel_id, active
    ) VALUES (
        cg_name, nap_id, true
    );
    -- Outnet
    INSERT INTO system_config.config_group (
        name, channel_id, active
    ) VALUES (
        cg_name, outnet_id, false
    );
    -- MrP
    INSERT INTO system_config.config_group (
        name, channel_id, active
    ) VALUES (
        cg_name, mrp_id, true
    );

END;
$$ LANGUAGE plpgsql;

SELECT welcome_pack();
DROP FUNCTION welcome_pack();

COMMIT;;
