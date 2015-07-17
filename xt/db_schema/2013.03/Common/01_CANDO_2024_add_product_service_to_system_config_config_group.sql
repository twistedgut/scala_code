-- CANDO-2024: Add Product Service to system_config.config_group

BEGIN WORK;

--
-- NAP
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Product_Service',
      ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'access_product_service', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'access_product_service_for_email', 'On', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' )
      ), 'access_product_service_for_default_language', 'Off', 0, 't'
    );

--
-- MRP
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Product_Service',
      ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'access_product_service', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'access_product_service_for_email', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' )
      ), 'access_product_service_for_default_language', 'Off', 0, 't'
    );

--
-- theOutnet.com
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Product_Service',
      ( SELECT id FROM channel WHERE name = 'theOutnet.com' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'access_product_service', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'access_product_service_for_email', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' )
      ), 'access_product_service_for_default_language', 'Off', 0, 't'
    );

--
-- JIMMYCHOO.COM
--
INSERT INTO system_config.config_group (name, channel_id, active) VALUES
    ( 'Product_Service',
      ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' ),
      't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'access_product_service', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'access_product_service_for_email', 'Off', 0, 't'
    );

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value, sequence, active)
    VALUES
    ( ( SELECT id FROM system_config.config_group WHERE
        name = 'Product_Service' AND
        channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' )
      ), 'access_product_service_for_default_language', 'Off', 0, 't'
    );


COMMIT WORK;
