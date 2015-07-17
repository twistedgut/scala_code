BEGIN;

INSERT INTO ship_restriction (title, code) VALUES ( 'Hazmat EQ', 'HZMT_EQ' );
INSERT INTO ship_restriction (title, code) VALUES ( 'Hazmat Aerosol', 'HZMT_AERO' );

INSERT INTO ship_restriction_location (ship_restriction_id, location, type) (
    SELECT
        (SELECT id FROM ship_restriction WHERE code = 'HZMT_EQ'),
        code,
        'COUNTRY'
    FROM country
    WHERE country IN (
        'Algeria',
        'Antigua and Barbuda',
        'Cameroon',
        'China',
        'Gabon',
        'Ghana',
        'Guam',
        'Marshall Islands',
        'Palau',
        'Puerto Rico',
        'Taiwan ROC',
        'Togo',
        'Tunisia',
        'US Virgin Islands'
        'Vietnam'
    )
);

COMMIT;
