--
-- CANDO-2472: Add system config entries for multi tender shipping notice
--

BEGIN WORK;

INSERT INTO system_config.config_group ( name, active )
VALUES ( 'Multi_Tender_Shipping_Notice', true );

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    active
)
VALUES (
    ( SELECT id FROM system_config.config_group
                WHERE name = 'Multi_Tender_Shipping_Notice' ),
    'Russia',
    1,
    true
);

COMMIT WORK;
