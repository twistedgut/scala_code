-- DCOP-893
-- DC1 associate Madagascar with international shipping charge for NAP and MRP

BEGIN;

insert into country_shipping_charge(country_id, shipping_charge_id, channel_id)
values
(
    -- NAP
    (select id from country where country = 'Madagascar'),
    (select id from shipping_charge where sku = '900000-001'),
    (select id from channel where web_name like 'NAP%')
),
(
    -- MRP
    (select id from country where country = 'Madagascar'),
    (select id from shipping_charge where sku = '910000-001'),
    (select id from channel where web_name like 'MRP%')
);

COMMIT;
