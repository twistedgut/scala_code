-- CANDO-1601: Update country_shipment_type with new DC3 values

BEGIN WORK;

UPDATE country_shipment_type
SET shipment_type_id = (
    SELECT id
    FROM shipment_type
    WHERE type = 'Domestic'
),
auto_ddu = false
WHERE country_id = (
    SELECT id
    FROM country
    WHERE country = 'Hong Kong'
);

UPDATE country_shipment_type
SET shipment_type_id = (
    SELECT id
    FROM shipment_type
    WHERE type = 'International'
)
WHERE country_id = (
    SELECT id
    FROM country
    WHERE country = 'United States'
);

COMMIT WORK;
