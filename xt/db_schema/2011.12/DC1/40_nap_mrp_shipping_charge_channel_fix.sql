


BEGIN;


-- FLEX-184

-- Add shipping_charge_country mappings to the new International Road skus for NAP/MRP



-- Clean out bad data

-- These were assigned to the combined NAP/MRP skus
DELETE
FROM country_shipping_charge csc
USING shipping_charge sc
WHERE
        csc.shipping_charge_id = sc.id
    AND csc.channel_id != sc.channel_id
;


DELETE
FROM postcode_shipping_charge psc
USING shipping_charge sc
WHERE
        psc.shipping_charge_id = sc.id
    AND psc.channel_id != sc.channel_id
;





-- Re-fill country_shipping_charge with the corresponding old NAP /
-- new MRP shipping_charge rows

-- MRP:910000-001 NAP:900000-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910000-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900000-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910001-001 NAP:900001-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910001-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900001-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910002-001 NAP:900002-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910002-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900002-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910003-001 NAP:900003-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910003-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900003-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910004-001 NAP:900004-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910004-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900004-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910005-001 NAP:900005-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910005-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900005-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910008-001 NAP:900008-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910008-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900008-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );







-- Re-fill postcode_shipping_charge with the corresponding old NAP /
-- new MRP shipping_charge rows

-- MRP:910000-001 NAP:900000-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910000-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900000-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910001-001 NAP:900001-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910001-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900001-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910002-001 NAP:900002-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910002-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900002-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910003-001 NAP:900003-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910003-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900003-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910004-001 NAP:900004-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910004-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900004-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910005-001 NAP:900005-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910005-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900005-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910008-001 NAP:900008-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910008-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900008-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );

-- MRP:910008-001 NAP:900008-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910008-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900008-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );



-- state_shipping_charge (DC2 only)



COMMIT;
