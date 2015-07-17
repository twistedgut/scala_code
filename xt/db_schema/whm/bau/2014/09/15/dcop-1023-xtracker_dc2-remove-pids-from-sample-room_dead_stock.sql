BEGIN;

-- PID 399564

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN location l ON l.id = q.location_id
            JOIN variant v ON v.id = q.variant_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 399564 AND size_id = 99)
    )
    AND l.location IN (
        'Sample Room'
    )
    AND q.quantity <= 2
);

--PID 401876

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN location l ON l.id = q.location_id
            JOIN variant v ON v.id = q.variant_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 401876 AND size_id = 14)
    )
    AND l.location IN (
        'Sample Room'
    )
    AND q.quantity <= 2
);

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN variant v ON v.id = q.variant_id
            JOIN flow.status f ON f.id = q.status_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 401876 AND size_id = 12)
    )
    AND f.name IN (
        'Dead Stock'
    )
    AND q.quantity <= 2
);

INSERT INTO log_rtv_stock VALUES (
   default,
   3776283, 
   (SELECT id FROM rtv_action WHERE action = 'Manual Adjustment'), 
   1, 
   'Removed from dead stock (DCOP-1023)', 
   -1, 
   0, 
   current_timestamp, 
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

INSERT INTO log_location (variant_id,location_id,operator_id,channel_id) VALUES (
   3776283,
   231343,
   1,
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN variant v ON v.id = q.variant_id
            JOIN flow.status f ON f.id = q.status_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 401876 AND size_id = 16)
    )
    AND f.name IN (
        'Dead Stock'
    )
    AND q.quantity <= 2
);

INSERT INTO log_rtv_stock VALUES (
   default,
   3776279, 
   (SELECT id FROM rtv_action WHERE action = 'Manual Adjustment'), 
   1, 
   'Removed from dead stock (DCOP-1023)', 
   -1, 
   0, 
   current_timestamp, 
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

INSERT INTO log_location (variant_id,location_id,operator_id,channel_id) VALUES (
   3776279,
   231343,
   1,
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

--PID 402722

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN variant v ON v.id = q.variant_id
            JOIN flow.status f ON f.id = q.status_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 402722 AND size_id = 5)
    )
    AND f.name IN (
        'Dead Stock'
    )
    AND q.quantity <= 2
);

INSERT INTO log_rtv_stock VALUES (
   default,
   3831596, 
   (SELECT id FROM rtv_action WHERE action = 'Manual Adjustment'), 
   1, 
   'Removed from dead stock (DCOP-1023)', 
   -1, 
   0, 
   current_timestamp, 
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

INSERT INTO log_location (variant_id,location_id,operator_id,channel_id) VALUES (
   3831596,
   231343,
   1,
   (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

DELETE FROM quantity
WHERE id IN (
    SELECT  q.id
    FROM    quantity q
            JOIN location l ON l.id = q.location_id
            JOIN variant v ON v.id = q.variant_id
    WHERE   q.variant_id IN (
        SELECT  id
        FROM    variant
        WHERE   (product_id = 402722 AND size_id = 5)
    )
    AND l.location IN (
        'Styling'
    )
    AND q.quantity <= 2
);

COMMIT;
