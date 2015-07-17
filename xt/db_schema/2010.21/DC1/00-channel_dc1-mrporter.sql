BEGIN;


INSERT INTO public.channel (
id, name, business_id, distrib_centre_id, web_name, is_enabled
) VALUES (
5,
'MrPorter.com',
(SELECT id FROM public.business WHERE name = 'MrPorter.com'),
(SELECT id FROM public.distrib_centre WHERE name = 'DC1'),
'MRP-INTL',
TRUE
);


COMMIT;
