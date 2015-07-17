BEGIN;

-- FLEX-183
-- Add shipping_charge_country mappings to the new International Road skus for NAP/MRP


-- 2-3 days
-- NAP
insert into country_shipping_charge (country_id, shipping_charge_id, channel_id)
    select
        c.id,
        (select id from shipping_charge where sku  = '9000203-001'),
        (select id from channel         where name = 'NET-A-PORTER.COM')
    from country c
    where c.country in ('Austria', 'Belgium', 'Czech Republic', 'Denmark', 'France', 'Germany', 'Hungary', 'Ireland', 'Italy', 'Luxembourg', 'Netherlands', 'Poland', 'Portugal', 'Slovakia', 'Slovenia', 'Spain', 'Sweden' );

-- MRP
insert into country_shipping_charge (country_id, shipping_charge_id, channel_id)
    select
        c.id,
        (select id from shipping_charge where sku  = '9010203-001'),
        (select id from channel         where name = 'MRPORTER.COM')
    from country c
    where c.country in ('Austria', 'Belgium', 'Czech Republic', 'Denmark', 'France', 'Germany', 'Hungary', 'Ireland', 'Italy', 'Luxembourg', 'Netherlands', 'Poland', 'Portugal', 'Slovakia', 'Slovenia', 'Spain', 'Sweden' );



-- 4-5 days
-- NAP
insert into country_shipping_charge (country_id, shipping_charge_id, channel_id)
    select
        c.id,
        (select id from shipping_charge where sku  = '9000204-001'),
        (select id from channel         where name = 'NET-A-PORTER.COM')
    from country c
    where c.country in ( 'Bulgaria', 'Estonia', 'Finland', 'Greece', 'Latvia', 'Lithuania', 'Norway', 'Romania', 'Switzerland' );

-- MRP
insert into country_shipping_charge (country_id, shipping_charge_id, channel_id)
    select
        c.id,
        (select id from shipping_charge where sku  = '9010204-001'),
        (select id from channel         where name = 'MRPORTER.COM')
    from country c
    where c.country in ( 'Bulgaria', 'Estonia', 'Finland', 'Greece', 'Latvia', 'Lithuania', 'Norway', 'Romania', 'Switzerland' );


COMMIT;
