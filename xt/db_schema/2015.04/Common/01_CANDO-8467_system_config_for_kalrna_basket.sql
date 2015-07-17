-- Ticket       : CANDO-8467
-- Description  : Adding a System Config entry for Sku  and name for Klarna payment amendement
--                calls used by XT::Domain::Payment::Basket.

BEGIN WORK;

INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
) VALUES (
    'PSPNamespace',
    NULL,
    TRUE
);

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    sequence,
    active
) VALUES (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'giftvoucher_sku',
        'gift_voucher',
        0,
        TRUE
    ),
    (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'giftvoucher_name',
        'Gift Voucher',
        0,
        TRUE
    ),
    (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'storecredit_sku',
        'store_credit',
        0,
        TRUE
    ),
    (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'storecredit_name',
        'Store Credit',
        0,
        TRUE
    ),
    (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'shipping_sku',
        'shipping',
        0,
        TRUE
    ),
    (
        ( SELECT id FROM system_config.config_group WHERE name = 'PSPNamespace' ),
        'shipping_name',
        'Shipping',
        0,
        TRUE
    );


COMMIT;

