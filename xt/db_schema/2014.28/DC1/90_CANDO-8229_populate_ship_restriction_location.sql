--CANDO-8229: Populate Shipping restriction countries for LQ-Hazmat  products.

BEGIN WORK;


INSERT INTO ship_restriction_location (ship_restriction_id, location, type) (
    SELECT
        (SELECT id from  ship_restriction where code='HZMT_LQ'),
        code,
        'COUNTRY'
    FROM country
    WHERE country NOT IN (
        'Austria',
        'Luxembourg',
        'Belgium',
        'Netherlands',
        'Czech Republic',
        'Norway',
        'Denmark',
        'Poland',
        'Ireland',
        'Portugal',
        'Estonia',
        'Slovakia',
        'France',
        'Slovenia',
        'Germany',
        'Spain',
        'Guernsey',
        'Switzerland',
        'Hungary',
        'Sweden',
        'Italy',
        'Jersey',
        'Latvia',
        'Lithuania',
        'United Kingdom'
    ) AND country != 'Unknown'
);
COMMIT WORK;
