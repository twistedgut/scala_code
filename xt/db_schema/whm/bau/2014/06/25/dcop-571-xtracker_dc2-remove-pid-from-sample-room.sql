BEGIN;

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN location l ON l.id = q.location_id
            JOIN variant v ON v.id = q.variant_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 398110 AND size_id = 5)
    )
    AND l.location IN (
        'Sample Room'
    )
    AND q.quantity <= 2
);

COMMIT;
