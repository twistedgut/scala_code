


BEGIN;


-- FLEX-184

-- Add shipping_charge_country mappings to the new International Road skus for NAP/MRP

-- This is a fix to sort out a systematic typo in the previous fix :/


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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900039-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900041-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900043-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900045-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900047-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900049-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900051-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900055-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900057-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900059-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900061-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900063-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900065-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900067-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900069-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900071-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900077-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900079-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900081-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900083-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900085-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900087-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900089-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900091-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900093-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900095-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900097-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900099-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000101-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000103-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000105-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000107-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000109-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000111-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000113-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000115-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000117-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000132-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000133-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000134-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000135-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000136-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000137-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000138-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000139-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000140-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000141-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900039-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900041-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900043-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900045-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900047-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900049-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900051-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900055-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900057-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900059-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900061-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900063-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900065-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900067-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900069-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900071-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900077-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900079-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900081-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900083-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900085-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900087-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900089-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900091-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900093-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900095-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900097-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900099-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000101-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000103-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000105-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000107-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000109-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000111-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000113-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000115-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000117-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000132-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000133-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000134-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000135-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000136-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000137-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000138-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000139-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000140-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000141-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900039-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900041-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900043-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900045-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900047-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900049-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900051-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900055-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900057-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900059-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900061-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900063-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900065-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900067-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900069-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900071-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900077-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900079-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900081-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900083-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900085-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900087-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900089-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900091-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900093-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900095-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900097-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900099-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000101-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000103-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000105-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000107-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000109-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000111-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000113-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000115-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000117-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000132-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000133-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000134-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000135-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000136-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000137-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000138-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000139-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000140-002' AND channel_id = (
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
        SELECT ch.id FROM shipping_charge ch WHERE sku = '9000141-002' AND channel_id = (
            SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'
        )
    );


COMMIT;
