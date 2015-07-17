-- adding sort order for some product type measurements (MRPBLK-330)

BEGIN;

ALTER TABLE public.product_type_measurement 
    ADD COLUMN sort_order INTEGER;

UPDATE public.product_type_measurement ptm
SET sort_order = 1 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Chest');

UPDATE public.product_type_measurement ptm
SET sort_order = 2 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Shoulder');

UPDATE public.product_type_measurement ptm
SET sort_order = 3 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Sleeve Length');

UPDATE public.product_type_measurement ptm
SET sort_order = 4 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Back Length');

UPDATE public.product_type_measurement ptm
SET sort_order = 5 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Jacket Waist');

UPDATE public.product_type_measurement ptm
SET sort_order = 6 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Armhole Diameter');

UPDATE public.product_type_measurement ptm
SET sort_order = 7 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Drop');

UPDATE public.product_type_measurement ptm
SET sort_order = 8 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Trouser Waist');

UPDATE public.product_type_measurement ptm
SET sort_order = 9 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Inside_Leg');

UPDATE public.product_type_measurement ptm
SET sort_order = 10 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Outside Leg');

UPDATE public.product_type_measurement ptm
SET sort_order = 11
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Rise');

UPDATE public.product_type_measurement ptm
SET sort_order = 12 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Leg Opening');

UPDATE public.product_type_measurement ptm
SET sort_order = 13 
WHERE ptm.product_type_id = (SELECT id FROM product_type WHERE product_type = 'Suits')
AND ptm.channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
AND ptm.measurement_id = (SELECT id FROM measurement WHERE measurement = 'Belt Loop');

COMMIT;
