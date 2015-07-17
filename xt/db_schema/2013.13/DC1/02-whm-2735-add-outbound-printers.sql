BEGIN;

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Shipping Document 1', 'jc_shippingdocument01', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='ShippingDocumentPrinters')
)
FROM system_config.config_group
WHERE name = 'ShippingDocumentPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Shipping Label 1', 'jc_shippinglabel01', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='ShippingLabelPrinters')
)
FROM system_config.config_group
WHERE name = 'ShippingLabelPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Premier Shipping 1', 'jc_premiershipping01', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PremierShippingPrinters')
)
FROM system_config.config_group
WHERE name = 'PremierShippingPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Premier Address Card 1', 'jc_premiercard01', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PremierAddressCardPrinters')
)
FROM system_config.config_group
WHERE name = 'PremierAddressCardPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Shipping Document 2', 'jc_shippingdocument02', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='ShippingDocumentPrinters')
)
FROM system_config.config_group
WHERE name = 'ShippingDocumentPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Shipping Label 2', 'jc_shippinglabel02', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='ShippingLabelPrinters')
)
FROM system_config.config_group
WHERE name = 'ShippingLabelPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Premier Shipping 2', 'jc_premiershipping02', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PremierShippingPrinters')
)
FROM system_config.config_group
WHERE name = 'PremierShippingPrinters';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, sequence)
SELECT id, 'JC Premier Address Card 2', 'jc_premiercard02', (
    select max(sequence)+1
    from system_config.config_group_setting
    where config_group_id in (select id from system_config.config_group where name='PremierAddressCardPrinters')
)
FROM system_config.config_group
WHERE name = 'PremierAddressCardPrinters';

COMMIT;
