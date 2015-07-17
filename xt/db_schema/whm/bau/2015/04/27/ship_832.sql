BEGIN;

    -- Add restrictions for 'BIKE' shipping-attribute

    INSERT INTO ship_restriction_location(ship_restriction_id, location, type) VALUES
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Algeria'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Andorra'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Argentina'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Australia'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Belarus'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Brazil'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Colombia'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Ecuador'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Jordan'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Kazakhstan'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Moldova'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'New Zealand'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Thailand'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'Turkey'),
            'COUNTRY'
        ),
        (
            (SELECT id FROM ship_restriction WHERE code = 'BIKE'),
            (SELECT code FROM country WHERE country = 'United Arab Emirates'),
            'COUNTRY'
        )
    ;

COMMIT;
