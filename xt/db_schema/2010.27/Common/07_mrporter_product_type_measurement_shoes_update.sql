-- update product type measurements mappings for mr porter shoes

BEGIN;

--measurements that might not exist yet

CREATE OR REPLACE FUNCTION create_measurement_ignore_duplicate(measurement_name TEXT)
RETURNS VOID AS $$
BEGIN 
    
    BEGIN
        INSERT INTO public.measurement (measurement)  
            VALUES (measurement_name);
    EXCEPTION WHEN unique_violation THEN
        -- ignore duplicate errors 
    END;
END;
$$ LANGUAGE plpgsql;

SELECT create_measurement_ignore_duplicate('Depth of Heel');
SELECT create_measurement_ignore_duplicate('Height of Heel');
    
DROP FUNCTION create_measurement_ignore_duplicate(TEXT);


-- delete existing shoes mappings and create new ones

CREATE OR REPLACE FUNCTION update_measurement_mapping()
RETURNS VOID AS $$
DECLARE
    pt_id INTEGER;
    mrp_id INTEGER;

BEGIN

    SELECT id INTO mrp_id FROM channel WHERE upper(name)='MRPORTER.COM';

    SELECT id INTO pt_id FROM product_type WHERE product_type='Casual';
    DELETE FROM product_type_measurement WHERE product_type_id=pt_id AND channel_id=mrp_id;
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Height of Heel', 'Depth of Heel','Sole');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Formal';
    DELETE FROM product_type_measurement WHERE product_type_id=pt_id AND channel_id=mrp_id;
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Height of Heel', 'Depth of Heel','Sole');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Boots';
    DELETE FROM product_type_measurement WHERE product_type_id=pt_id AND channel_id=mrp_id;
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Height of Heel', 'Depth of Heel','Sole');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Sneakers';
    DELETE FROM product_type_measurement WHERE product_type_id=pt_id AND channel_id=mrp_id;
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Height of Heel', 'Depth of Heel','Sole');


END;
$$ LANGUAGE plpgsql;

SELECT update_measurement_mapping();
DROP FUNCTION update_measurement_mapping();

COMMIT;
