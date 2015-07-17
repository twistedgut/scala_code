-- add new product types, new measurements and mappings for mr porter

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

SELECT create_measurement_ignore_duplicate('Back Length');
SELECT create_measurement_ignore_duplicate('Chest');
SELECT create_measurement_ignore_duplicate('Collar');
SELECT create_measurement_ignore_duplicate('Euro');
SELECT create_measurement_ignore_duplicate('Handle Length');
SELECT create_measurement_ignore_duplicate('Japanese');
SELECT create_measurement_ignore_duplicate('Outside Leg');
SELECT create_measurement_ignore_duplicate('Width of Detail');
SELECT create_measurement_ignore_duplicate('UK');
SELECT create_measurement_ignore_duplicate('US');

DROP FUNCTION create_measurement_ignore_duplicate(TEXT);


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

SELECT create_product_type_ignore_duplicate('Cufflinks');
SELECT create_product_type_ignore_duplicate('Handkerchiefs');
SELECT create_product_type_ignore_duplicate('Jewellery');
SELECT create_product_type_ignore_duplicate('Nightwear');
SELECT create_product_type_ignore_duplicate('Polos');
SELECT create_product_type_ignore_duplicate('Shirts');
SELECT create_product_type_ignore_duplicate('Socks');
SELECT create_product_type_ignore_duplicate('Sweats');
SELECT create_product_type_ignore_duplicate('Swim');
SELECT create_product_type_ignore_duplicate('T-Shirts');
SELECT create_product_type_ignore_duplicate('Trousers');
SELECT create_product_type_ignore_duplicate('Underwear');

DROP FUNCTION create_product_type_ignore_duplicate(TEXT);


-- and finally the mapping

DELETE FROM public.product_type_measurement
    WHERE channel_id = (SELECT id FROM channel WHERE upper(name)='MRPORTER.COM');

CREATE OR REPLACE FUNCTION measurement_mapping()
RETURNS VOID AS $$
DECLARE
    pt_id INTEGER;
    mrp_id INTEGER;

BEGIN

    SELECT id INTO mrp_id FROM channel WHERE upper(name)='MRPORTER.COM';

    SELECT id INTO pt_id FROM product_type WHERE product_type='Shirts';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Collar','Shoulder','Waist','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='T-Shirts';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Polos';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Collar','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Trousers';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise','Leg Opening');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Shorts';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise','Leg Opening');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Swim';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Jeans';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise','Leg Opening');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Knitwear';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Sweats';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Jackets';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Shoulder','Waist','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Coats';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Shoulder','Waist','Back Length','Sleeve');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Suits';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Chest','Shoulder','Waist','Drop','Back Length','Sleeve','Inside_Leg','Outside Leg','Rise','Leg Opening');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Bags';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Width','Depth','Handle Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Wallets';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Height','Width','Depth');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Watches';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Min. Strap Length','Max. Strap Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Jewellery';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Pendant Width','Pendant Length','Circumference','Width of Opening','Width of Detail','Chain Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Cufflinks';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Lifestyle';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length','Depth');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Belts';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length','Maximum','Minimum');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Ties';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Gloves';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length','Circumference');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Hats';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length','Circumference','Height');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Scarves';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Handkerchiefs';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Umbrellas';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Width','Length','Handle Length');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Sunglasses';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Frame Height','Frame Width');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Underwear';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Nightwear';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('Waist','Inside_Leg','Outside Leg','Rise','Chest','Length','Sleeve','Leg Opening','UK','US','Euro','Japanese');

    SELECT id INTO pt_id FROM product_type WHERE product_type='Socks';
    INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
        SELECT pt_id, id, mrp_id 
        FROM measurement
        WHERE measurement in ('UK','US','Euro','Japanese');


END;
$$ LANGUAGE plpgsql;

SELECT measurement_mapping();
DROP FUNCTION measurement_mapping();

COMMIT;
