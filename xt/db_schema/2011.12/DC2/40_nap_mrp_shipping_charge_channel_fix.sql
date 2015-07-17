


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
    AND sc.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    AND csc.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
;


DELETE
FROM postcode_shipping_charge psc
USING shipping_charge sc
WHERE
        psc.shipping_charge_id = sc.id
    AND psc.channel_id != sc.channel_id
    AND sc.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    AND psc.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
;


DELETE
FROM state_shipping_charge ssc
USING shipping_charge sc
WHERE
        ssc.shipping_charge_id = sc.id
    AND ssc.channel_id != sc.channel_id
    AND sc.channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    AND ssc.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
;

-- Note: after this cleanup, there is still country_shipping_charge
-- rows assigned to the wrong channel (according to the
-- shipping_charge.channel_id).





-- Re-fill country_shipping_charge with the corresponding old NAP /
-- new MRP shipping_charge rows

-- MRP: 910012-001, NAP: 900012-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910012-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900012-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910013-001, NAP: 900013-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910013-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900013-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910014-001, NAP: 900014-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910014-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900014-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910026-001, NAP: 900026-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910026-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900026-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910027-001, NAP: 900027-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910027-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900027-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910028-001, NAP: 900028-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910028-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900028-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910029-001, NAP: 900029-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910029-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900029-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910030-001, NAP: 900030-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910030-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900030-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910031-001, NAP: 900031-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910031-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900031-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910032-001, NAP: 900032-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910032-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900032-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910033-001, NAP: 900033-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910033-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900033-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910034-001, NAP: 900034-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910034-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900034-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910035-001, NAP: 900035-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910035-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900035-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910036-001, NAP: 900036-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910036-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900036-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910038-001, NAP: 900038-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910038-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900038-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910040-001, NAP: 900040-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910040-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900040-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910042-001, NAP: 900042-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910042-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900042-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910044-001, NAP: 900044-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910044-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900044-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910046-001, NAP: 900046-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910046-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900046-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910048-001, NAP: 900048-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910048-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900048-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910050-001, NAP: 900050-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910050-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900050-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910052-001, NAP: 900052-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910052-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900052-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910054-001, NAP: 900054-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910054-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900054-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910056-001, NAP: 900056-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910056-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900056-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910058-001, NAP: 900058-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910058-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900058-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910060-001, NAP: 900060-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910060-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900060-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910062-001, NAP: 900062-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910062-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900062-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910064-001, NAP: 900064-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910064-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900064-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910066-001, NAP: 900066-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910066-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900066-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910068-001, NAP: 900068-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910068-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900068-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910070-001, NAP: 900070-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910070-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900070-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910072-001, NAP: 900072-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910072-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900072-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910074-001, NAP: 900074-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910074-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900074-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910076-001, NAP: 900076-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910076-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900076-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910078-001, NAP: 900078-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910078-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900078-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910080-001, NAP: 900080-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910080-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900080-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910082-001, NAP: 900082-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910082-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900082-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910084-001, NAP: 900084-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910084-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900084-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910086-001, NAP: 900086-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910086-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900086-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910088-001, NAP: 900088-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910088-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900088-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910090-001, NAP: 900090-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910090-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900090-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910092-001, NAP: 900092-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910092-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900092-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910094-001, NAP: 900094-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910094-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900094-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910096-001, NAP: 900096-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910096-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900096-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910098-001, NAP: 900098-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910098-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900098-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010100-001, NAP: 9000100-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010100-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000100-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010102-001, NAP: 9000102-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010102-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000102-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010104-001, NAP: 9000104-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010104-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000104-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010106-001, NAP: 9000106-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010106-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000106-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010108-001, NAP: 9000108-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010108-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000108-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010110-001, NAP: 9000110-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010110-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000110-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010112-001, NAP: 9000112-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010112-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000112-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010114-001, NAP: 9000114-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010114-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000114-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010116-001, NAP: 9000116-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010116-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000116-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010203-001, NAP: 9000203-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010203-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000203-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010205-001, NAP: 9000205-001
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010205-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000205-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910025-001, NAP:900025-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910025-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00025-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910039-001, NAP:900039-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910039-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00039-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910041-001, NAP:900041-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910041-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00041-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910043-001, NAP:900043-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910043-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00043-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910045-001, NAP:900045-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910045-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00045-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910047-001, NAP:900047-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910047-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00047-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910049-001, NAP:900049-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910049-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00049-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910051-001, NAP:900051-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910051-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00051-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910055-001, NAP:900055-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910055-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00055-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910057-001, NAP:900057-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910057-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00057-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910059-001, NAP:900059-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910059-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00059-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910061-001, NAP:900061-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910061-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00061-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910063-001, NAP:900063-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910063-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00063-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910065-001, NAP:900065-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910065-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00065-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910067-001, NAP:900067-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910067-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00067-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910069-001, NAP:900069-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910069-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00069-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910071-001, NAP:900071-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910071-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00071-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910077-001, NAP:900077-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910077-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00077-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910079-001, NAP:900079-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910079-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00079-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910081-001, NAP:900081-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910081-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00081-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910083-001, NAP:900083-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910083-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00083-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910085-001, NAP:900085-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910085-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00085-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910087-001, NAP:900087-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910087-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00087-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910089-001, NAP:900089-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910089-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00089-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910091-001, NAP:900091-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910091-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00091-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910093-001, NAP:900093-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910093-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00093-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910095-001, NAP:900095-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910095-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00095-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910097-001, NAP:900097-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910097-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00097-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910099-001, NAP:900099-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910099-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00099-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010101-001, NAP:9000101-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010101-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000101-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010103-001, NAP:9000103-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010103-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000103-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010105-001, NAP:9000105-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010105-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000105-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010107-001, NAP:9000107-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010107-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000107-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010109-001, NAP:9000109-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010109-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000109-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010111-001, NAP:9000111-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010111-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000111-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010113-001, NAP:9000113-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010113-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000113-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010115-001, NAP:9000115-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010115-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000115-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010117-001, NAP:9000117-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010117-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000117-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010132-001, NAP:9000132-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010132-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000132-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010133-001, NAP:9000133-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010133-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000133-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010134-001, NAP:9000134-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010134-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000134-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010135-001, NAP:9000135-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010135-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000135-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010136-001, NAP:9000136-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010136-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000136-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010137-001, NAP:9000137-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010137-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000137-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010138-001, NAP:9000138-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010138-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000138-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010139-001, NAP:9000139-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010139-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000139-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010140-001, NAP:9000140-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010140-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000140-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010141-001, NAP:9000141-002
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        csc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010141-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country_shipping_charge csc
    JOIN country c ON (c.id = csc.country_id)
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000141-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );










-- Re-fill postcode_shipping_charge with the corresponding old NAP /
-- new MRP shipping_charge rows

-- MRP: 910012-001, NAP: 900012-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910012-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900012-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910013-001, NAP: 900013-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910013-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900013-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910014-001, NAP: 900014-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910014-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900014-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910026-001, NAP: 900026-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910026-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900026-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910027-001, NAP: 900027-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910027-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900027-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910028-001, NAP: 900028-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910028-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900028-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910029-001, NAP: 900029-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910029-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900029-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910030-001, NAP: 900030-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910030-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900030-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910031-001, NAP: 900031-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910031-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900031-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910032-001, NAP: 900032-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910032-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900032-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910033-001, NAP: 900033-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910033-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900033-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910034-001, NAP: 900034-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910034-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900034-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910035-001, NAP: 900035-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910035-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900035-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910036-001, NAP: 900036-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910036-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900036-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910038-001, NAP: 900038-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910038-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900038-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910040-001, NAP: 900040-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910040-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900040-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910042-001, NAP: 900042-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910042-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900042-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910044-001, NAP: 900044-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910044-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900044-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910046-001, NAP: 900046-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910046-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900046-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910048-001, NAP: 900048-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910048-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900048-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910050-001, NAP: 900050-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910050-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900050-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910052-001, NAP: 900052-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910052-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900052-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910054-001, NAP: 900054-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910054-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900054-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910056-001, NAP: 900056-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910056-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900056-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910058-001, NAP: 900058-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910058-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900058-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910060-001, NAP: 900060-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910060-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900060-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910062-001, NAP: 900062-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910062-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900062-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910064-001, NAP: 900064-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910064-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900064-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910066-001, NAP: 900066-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910066-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900066-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910068-001, NAP: 900068-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910068-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900068-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910070-001, NAP: 900070-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910070-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900070-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910072-001, NAP: 900072-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910072-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900072-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910074-001, NAP: 900074-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910074-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900074-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910076-001, NAP: 900076-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910076-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900076-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910078-001, NAP: 900078-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910078-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900078-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910080-001, NAP: 900080-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910080-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900080-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910082-001, NAP: 900082-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910082-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900082-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910084-001, NAP: 900084-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910084-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900084-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910086-001, NAP: 900086-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910086-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900086-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910088-001, NAP: 900088-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910088-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900088-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910090-001, NAP: 900090-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910090-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900090-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910092-001, NAP: 900092-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910092-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900092-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910094-001, NAP: 900094-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910094-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900094-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910096-001, NAP: 900096-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910096-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900096-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910098-001, NAP: 900098-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910098-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900098-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010100-001, NAP: 9000100-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010100-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000100-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010102-001, NAP: 9000102-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010102-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000102-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010104-001, NAP: 9000104-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010104-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000104-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010106-001, NAP: 9000106-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010106-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000106-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010108-001, NAP: 9000108-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010108-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000108-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010110-001, NAP: 9000110-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010110-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000110-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010112-001, NAP: 9000112-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010112-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000112-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010114-001, NAP: 9000114-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010114-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000114-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010116-001, NAP: 9000116-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010116-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000116-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010203-001, NAP: 9000203-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010203-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000203-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010205-001, NAP: 9000205-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010205-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000205-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910025-001, NAP:900025-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910025-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00025-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910039-001, NAP:900039-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910039-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00039-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910041-001, NAP:900041-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910041-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00041-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910043-001, NAP:900043-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910043-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00043-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910045-001, NAP:900045-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910045-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00045-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910047-001, NAP:900047-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910047-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00047-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910049-001, NAP:900049-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910049-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00049-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910051-001, NAP:900051-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910051-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00051-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910055-001, NAP:900055-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910055-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00055-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910057-001, NAP:900057-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910057-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00057-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910059-001, NAP:900059-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910059-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00059-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910061-001, NAP:900061-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910061-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00061-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910063-001, NAP:900063-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910063-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00063-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910065-001, NAP:900065-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910065-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00065-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910067-001, NAP:900067-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910067-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00067-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910069-001, NAP:900069-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910069-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00069-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910071-001, NAP:900071-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910071-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00071-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910077-001, NAP:900077-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910077-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00077-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910079-001, NAP:900079-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910079-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00079-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910081-001, NAP:900081-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910081-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00081-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910083-001, NAP:900083-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910083-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00083-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910085-001, NAP:900085-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910085-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00085-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910087-001, NAP:900087-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910087-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00087-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910089-001, NAP:900089-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910089-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00089-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910091-001, NAP:900091-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910091-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00091-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910093-001, NAP:900093-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910093-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00093-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910095-001, NAP:900095-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910095-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00095-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910097-001, NAP:900097-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910097-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00097-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910099-001, NAP:900099-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910099-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00099-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010101-001, NAP:9000101-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010101-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000101-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010103-001, NAP:9000103-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010103-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000103-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010105-001, NAP:9000105-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010105-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000105-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010107-001, NAP:9000107-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010107-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000107-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010109-001, NAP:9000109-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010109-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000109-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010111-001, NAP:9000111-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010111-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000111-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010113-001, NAP:9000113-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010113-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000113-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010115-001, NAP:9000115-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010115-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000115-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010117-001, NAP:9000117-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010117-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000117-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010132-001, NAP:9000132-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010132-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000132-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010133-001, NAP:9000133-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010133-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000133-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010134-001, NAP:9000134-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010134-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000134-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010135-001, NAP:9000135-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010135-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000135-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010136-001, NAP:9000136-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010136-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000136-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010137-001, NAP:9000137-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010137-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000137-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010138-001, NAP:9000138-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010138-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000138-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010139-001, NAP:9000139-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010139-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000139-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010140-001, NAP:9000140-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010140-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000140-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010141-001, NAP:9000141-002
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010141-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000141-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );





-- state_shipping_charge (DC2 only)

-- MRP: 910012-001, NAP: 900012-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910012-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900012-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910013-001, NAP: 900013-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910013-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900013-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910014-001, NAP: 900014-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910014-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900014-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910026-001, NAP: 900026-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910026-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900026-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910027-001, NAP: 900027-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910027-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900027-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910028-001, NAP: 900028-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910028-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900028-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910029-001, NAP: 900029-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910029-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900029-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910030-001, NAP: 900030-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910030-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900030-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910031-001, NAP: 900031-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910031-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900031-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910032-001, NAP: 900032-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910032-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900032-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910033-001, NAP: 900033-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910033-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900033-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910034-001, NAP: 900034-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910034-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900034-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910035-001, NAP: 900035-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910035-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900035-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910036-001, NAP: 900036-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910036-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900036-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910038-001, NAP: 900038-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910038-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900038-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910040-001, NAP: 900040-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910040-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900040-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910042-001, NAP: 900042-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910042-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900042-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910044-001, NAP: 900044-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910044-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900044-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910046-001, NAP: 900046-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910046-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900046-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910048-001, NAP: 900048-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910048-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900048-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910050-001, NAP: 900050-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910050-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900050-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910052-001, NAP: 900052-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910052-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900052-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910054-001, NAP: 900054-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910054-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900054-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910056-001, NAP: 900056-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910056-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900056-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910058-001, NAP: 900058-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910058-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900058-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910060-001, NAP: 900060-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910060-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900060-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910062-001, NAP: 900062-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910062-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900062-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910064-001, NAP: 900064-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910064-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900064-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910066-001, NAP: 900066-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910066-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900066-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910068-001, NAP: 900068-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910068-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900068-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910070-001, NAP: 900070-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910070-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900070-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910072-001, NAP: 900072-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910072-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900072-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910074-001, NAP: 900074-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910074-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900074-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910076-001, NAP: 900076-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910076-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900076-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910078-001, NAP: 900078-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910078-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900078-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910080-001, NAP: 900080-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910080-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900080-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910082-001, NAP: 900082-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910082-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900082-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910084-001, NAP: 900084-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910084-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900084-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910086-001, NAP: 900086-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910086-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900086-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910088-001, NAP: 900088-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910088-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900088-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910090-001, NAP: 900090-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910090-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900090-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910092-001, NAP: 900092-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910092-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900092-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910094-001, NAP: 900094-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910094-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900094-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910096-001, NAP: 900096-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910096-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900096-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910098-001, NAP: 900098-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910098-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900098-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010100-001, NAP: 9000100-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010100-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000100-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010102-001, NAP: 9000102-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010102-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000102-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010104-001, NAP: 9000104-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010104-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000104-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010106-001, NAP: 9000106-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010106-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000106-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010108-001, NAP: 9000108-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010108-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000108-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010110-001, NAP: 9000110-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010110-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000110-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010112-001, NAP: 9000112-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010112-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000112-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010114-001, NAP: 9000114-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010114-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000114-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010116-001, NAP: 9000116-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010116-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000116-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010203-001, NAP: 9000203-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010203-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000203-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010205-001, NAP: 9000205-001
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010205-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000205-001' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910025-001, NAP:900025-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910025-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00025-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910039-001, NAP:900039-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910039-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00039-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910041-001, NAP:900041-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910041-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00041-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910043-001, NAP:900043-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910043-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00043-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910045-001, NAP:900045-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910045-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00045-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910047-001, NAP:900047-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910047-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00047-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910049-001, NAP:900049-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910049-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00049-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910051-001, NAP:900051-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910051-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00051-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910055-001, NAP:900055-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910055-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00055-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910057-001, NAP:900057-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910057-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00057-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910059-001, NAP:900059-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910059-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00059-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910061-001, NAP:900061-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910061-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00061-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910063-001, NAP:900063-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910063-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00063-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910065-001, NAP:900065-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910065-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00065-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910067-001, NAP:900067-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910067-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00067-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910069-001, NAP:900069-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910069-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00069-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910071-001, NAP:900071-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910071-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00071-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910077-001, NAP:900077-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910077-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00077-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910079-001, NAP:900079-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910079-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00079-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910081-001, NAP:900081-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910081-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00081-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910083-001, NAP:900083-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910083-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00083-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910085-001, NAP:900085-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910085-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00085-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910087-001, NAP:900087-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910087-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00087-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910089-001, NAP:900089-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910089-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00089-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910091-001, NAP:900091-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910091-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00091-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910093-001, NAP:900093-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910093-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00093-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910095-001, NAP:900095-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910095-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00095-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910097-001, NAP:900097-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910097-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00097-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 910099-001, NAP:900099-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '910099-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '00099-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010101-001, NAP:9000101-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010101-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000101-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010103-001, NAP:9000103-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010103-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000103-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010105-001, NAP:9000105-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010105-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000105-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010107-001, NAP:9000107-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010107-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000107-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010109-001, NAP:9000109-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010109-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000109-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010111-001, NAP:9000111-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010111-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000111-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010113-001, NAP:9000113-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010113-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000113-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010115-001, NAP:9000115-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010115-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000115-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010117-001, NAP:9000117-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010117-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000117-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010132-001, NAP:9000132-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010132-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000132-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010133-001, NAP:9000133-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010133-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000133-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010134-001, NAP:9000134-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010134-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000134-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010135-001, NAP:9000135-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010135-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000135-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010136-001, NAP:9000136-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010136-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000136-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010137-001, NAP:9000137-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010137-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000137-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010138-001, NAP:9000138-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010138-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000138-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010139-001, NAP:9000139-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010139-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000139-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010140-001, NAP:9000140-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010140-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000140-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );
-- MRP: 9010141-001, NAP:9000141-002
INSERT INTO state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    SELECT
        ssc.state,
        ssc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9010141-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM state_shipping_charge ssc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '000141-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );


COMMIT;
