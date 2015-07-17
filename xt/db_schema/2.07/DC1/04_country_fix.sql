BEGIN;

UPDATE public.country SET code = 'MD' where country = 'Moldova';
UPDATE public.country SET code = 'BL' where country = 'St Barthelemy';

COMMIT;

