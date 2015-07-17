-- Insert short_name values for shoe and lingerie schemes

BEGIN;

    UPDATE size_scheme SET short_name = 'UK'
        WHERE name IN ('Lingerie', 'RTW - UK', 'Shoes - UK');

    UPDATE size_scheme SET short_name = 'IT'
        WHERE name IN ('RTW - Italy', 'Shoes - Italian');

    UPDATE size_scheme SET short_name = 'US'
        WHERE name IN ('RTW - US', 'Shoes - US');

    UPDATE size_scheme SET short_name = 'FR'
        WHERE name IN ('RTW - France', 'Shoes - France');

    UPDATE size_scheme SET short_name = 'DK'
        WHERE name IN ('RTW - Danish');

COMMIT;
