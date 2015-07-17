-- CANDO-7833: Language and update_customer_language_on_every_order settings

BEGIN WORK;

--
-- NAP
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Language',
      ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'EN', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'DE', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'FR', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'ZH', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'update_customer_language_on_every_order', 'Off', 0, 't'
    );

--
-- MRP
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Language',
      ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'EN', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'DE', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'FR', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'ZH', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'update_customer_language_on_every_order', 'Off', 0, 't'
    );

--
-- theOutnet.com
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Language',
      ( SELECT id FROM channel WHERE name = 'theOutnet.com' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'EN', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'DE', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'FR', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'ZH', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'update_customer_language_on_every_order', 'Off', 0, 't'
    );

--
-- JIMMYCHOO.COM
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Language',
      ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'EN', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'DE', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'FR', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'ZH', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Language' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'update_customer_language_on_every_order', 'On', 0, 't'
    );


COMMIT WORK;
