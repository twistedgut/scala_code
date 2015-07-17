BEGIN;

-- idx values are from ful
UPDATE public.channel SET idx = 2 WHERE web_name ilike 'NAP-AM';
UPDATE public.channel SET idx = 5 WHERE web_name ilike 'OUTNET-AM';
UPDATE public.channel SET idx = 8 WHERE web_name ilike 'MRP-AM';
UPDATE public.channel SET idx = 11 WHERE web_name ilike 'JC-AM';

COMMIT;
