-- add product type measurements mappings for mr porter shoes

BEGIN;

-- product types that might not exist yet

CREATE OR REPLACE FUNCTION create_product_type_ignore_duplicate(product_type_name TEXT)
RETURNS VOID AS $$
BEGIN

    BEGIN
        INSERT INTO public.product_type (product_type)
            VALUES (product_type_name);
    EXCEPTION WHEN unique_violation THEN
        -- ignore duplicate errors 
    END;
END;
$$ LANGUAGE plpgsql;

SELECT create_product_type_ignore_duplicate('Casual');
SELECT create_product_type_ignore_duplicate('Formal');

DROP FUNCTION create_product_type_ignore_duplicate(TEXT);


CREATE OR REPLACE FUNCTION measurement_mapping()
RETURNS VOID AS $$
DECLARE
    pt_id INTEGER;
    mrp_id INTEGER;

BEGIN

    SELECT id INTO mrp_id FROM channel WHERE upper(name)='MRPORTER.COM';

    SELECT id INTO pt_id FROM product_type WHERE product_type='Casual';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Euro','Japanese','UK','US');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Formal';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Euro','Japanese','UK','US');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Boots';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Euro','Japanese','UK','US');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Sneakers';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Euro','Japanese','UK','US');


END;
$$ LANGUAGE plpgsql;

SELECT measurement_mapping();
DROP FUNCTION measurement_mapping();

COMMIT;
