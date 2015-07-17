BEGIN;


INSERT INTO public.channel (
id, name, business_id, distrib_centre_id, web_name, is_enabled
) VALUES (
6,
'MrPorter.com',
(SELECT id FROM public.business WHERE name = 'MrPorter.com'),
(SELECT id FROM public.distrib_centre WHERE name = 'DC2'),
'MRP-AM',
TRUE
);


COMMIT;
