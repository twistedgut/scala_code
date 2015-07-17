-- Add a restriction on Fine Jewelry items being shipped to France for DC3 ONLY
BEGIN;
    INSERT INTO ship_restriction_location ( ship_restriction_id, location, type )
        VALUES
    (
        ( SELECT id FROM ship_restriction WHERE code = 'FINE_JEWEL' ),
        'FR',
        'COUNTRY'
    );
COMMIT;
