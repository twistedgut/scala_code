-- Add new measurements for product_types 'Formal Jackets' and 'Casual
-- Jackets'

BEGIN;

CREATE OR REPLACE FUNCTION add_jackets_measurements()
RETURNS VOID AS $$
DECLARE
    mrp_id INTEGER;
    pt_id INTEGER;

BEGIN
    SELECT id INTO mrp_id FROM channel WHERE name='MRPORTER.COM';

    SELECT id INTO pt_id FROM product_type WHERE product_type='Casual Jackets';
    INSERT INTO public.product_type_measurement ( product_type_id, measurement_id, channel_id )
        SELECT pt_id, id, mrp_id
          FROM measurement
         WHERE measurement IN ( 'Chest', 'Shoulder', 'Waist', 'Back Length', 'Sleeve Length', 'Drop', 'Armhole Diameter' );

    SELECT id INTO pt_id FROM product_type WHERE product_type='Formal Jackets';
    INSERT INTO public.product_type_measurement ( product_type_id, measurement_id, channel_id )
        SELECT pt_id, id, mrp_id
          FROM measurement
         WHERE measurement IN ( 'Chest', 'Shoulder', 'Waist', 'Back Length', 'Sleeve Length', 'Drop', 'Armhole Diameter' );
END;
$$ LANGUAGE plpgsql;

SELECT add_jackets_measurements();
DROP FUNCTION add_jackets_measurements();

COMMIT;
