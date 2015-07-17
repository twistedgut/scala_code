-- more changes for measurements - underwear updates
-- from "MR PORTER Product Classifications Measurements_v09_final list"

BEGIN;

CREATE OR REPLACE FUNCTION measurement_mapping()
RETURNS VOID AS $$
DECLARE
    pt_id INTEGER;
    mrp_id INTEGER;

BEGIN

    SELECT id INTO mrp_id FROM channel WHERE upper(name)='MRPORTER.COM';

    SELECT id INTO pt_id FROM product_type WHERE product_type='Underwear';

    -- clear existing underwear measurement types
    DELETE FROM public.product_type_measurement
        WHERE product_type_id = pt_id
        AND channel_id = mrp_id;
    -- add the "final" list of underwear measurements
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Leg Opening','Chest','Back Length','Sleeve Length');

END;
$$ LANGUAGE plpgsql;

SELECT measurement_mapping();
DROP FUNCTION measurement_mapping();

COMMIT;
