-- DC3: Create new currencies for new DC.

BEGIN WORK;

SELECT setval( pg_get_serial_sequence('currency', 'id'), ( SELECT MAX(id) FROM currency ) );

-- Insert Values
INSERT INTO currency ( currency ) VALUES
( 'HKD' ),
( 'CNY' ),
( 'KRW' );

COMMIT WORK;

