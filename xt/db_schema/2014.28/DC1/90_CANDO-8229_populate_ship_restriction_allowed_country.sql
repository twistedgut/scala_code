--CANDO-8229: Populate ship_restriction_allowed_country table


BEGIN WORK;


INSERT INTO ship_restriction_allowed_country (ship_restriction_id, country_id) (
    SELECT
        (SELECT id from  ship_restriction where code='HZMT_LQ'),
        id
    FROM country
    WHERE country IN (
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

    )
);
COMMIT WORK;

