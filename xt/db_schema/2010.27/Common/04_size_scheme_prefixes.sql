-- setting short_name for MRP size schemes to make the prefix 
-- appear on the website

BEGIN;

UPDATE size_scheme SET short_name = 'EU'
WHERE name IN ('M Shirts EU','M Shoes - EU full size','M Shoes - EU half size')
AND (short_name is null or short_name = '' );

UPDATE size_scheme SET short_name = 'FR'
WHERE name IN ('M RTW - FRANCE','M Shoes - FR full size')
AND (short_name is null or short_name = '' );

UPDATE size_scheme SET short_name = 'IT'
WHERE name IN ('M RTW - ITALY')
AND (short_name is null or short_name = '' );

UPDATE size_scheme SET short_name = 'UK'
WHERE name IN ('M RTW - UK','M Shirts UK','M Shoes - UK full size','M Shoes - UK half size')
AND (short_name is null or short_name = '' );

UPDATE size_scheme SET short_name = 'US'
WHERE name IN ('M RTW US','M RTW US SRL','M Shoes - US full size','M Shoes - US half size')
AND (short_name is null or short_name = '' );

-- these size schemes don't seem to exist everywhere yet, no harm in trying to
-- set short_name though in case they appear between now and when this finally
-- gets run on live
UPDATE size_scheme SET short_name = 'UK'
WHERE name IN ('M Shirts UK sleeves size','M RTW UK SRL')
AND (short_name is null or short_name = '' );

COMMIT;
