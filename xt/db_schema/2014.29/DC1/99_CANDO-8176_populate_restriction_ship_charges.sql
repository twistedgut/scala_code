-- CANDO-8176: Populate 'ship_restriction__shipping_charge' table to link
--             all of the available Shipping Charges for a Restriction

BEGIN WORK;

INSERT INTO ship_restriction_allowed_shipping_charge ( ship_restriction_id, shipping_charge_id )
SELECT  sr.id,
        sc.id
FROM    shipping_charge sc,
        ship_restriction sr
WHERE   sr.code = 'HZMT_LQ'
AND     (
    sc.id IN (
        SELECT  shipping_charge_id
        FROM    country_shipping_charge
        WHERE   country_id IN (
            SELECT  country_id
            FROM    ship_restriction_allowed_country
            WHERE   ship_restriction_id = sr.id
        )
    )
OR
    sc.id IN (
        SELECT  shipping_charge_id
        FROM    postcode_shipping_charge
        WHERE   country_id IN (
            SELECT  country_id
            FROM    ship_restriction_allowed_country
            WHERE   ship_restriction_id = sr.id
        )
    )
)
AND (
    sc.class_id in (
        select id
        from shipping_charge_class
        where class in ( 'Same Day', 'Ground' )
    )
OR
    -- all these are also allowed
    sc.sku IN (
        '9000521-001',      -- UK Standard (NAP)
        '900003-001',       -- UK Express (NAP)
        '920013-001',       -- Courier Special Delivery (NAP)
        '903000-001',       -- UK (TON)
        '920015-001',       -- Courier Special Delivery (TON)
        '9000421-001',      -- UK Standard (MRP)
        '910003-001',       -- UK Express (MRP)
        '920014-001',       -- Courier Special Delivery (MRP)
        'uklondonstandard'  -- UK/London Standard (JC)
    )
)
AND sc.is_enabled = TRUE
;

COMMIT WORK;
