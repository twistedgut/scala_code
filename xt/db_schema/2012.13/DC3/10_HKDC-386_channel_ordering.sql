BEGIN;

-- idx values are from ful
UPDATE public.channel SET idx = 3 WHERE web_name ilike 'NAP-APAC';
UPDATE public.channel SET idx = 6 WHERE web_name ilike 'OUTNET-APAC';
UPDATE public.channel SET idx = 9 WHERE web_name ilike 'MRP-APAC';
UPDATE public.channel SET idx = 12 WHERE web_name ilike 'JC-APAC';

COMMIT;
