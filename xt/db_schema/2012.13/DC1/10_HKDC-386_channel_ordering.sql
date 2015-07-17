BEGIN;

-- idx values are from ful
UPDATE public.channel SET idx = 1 WHERE web_name ilike 'NAP-INTL';
UPDATE public.channel SET idx = 4 WHERE web_name ilike 'OUTNET-INTL';
UPDATE public.channel SET idx = 7 WHERE web_name ilike 'MRP-INTL';
UPDATE public.channel SET idx = 10 WHERE web_name ilike 'JC-INTL';

COMMIT;
