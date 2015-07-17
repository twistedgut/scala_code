-- Fix autoincrement

BEGIN;

SELECT setval('process_group_id_seq', (SELECT MAX(group_id) FROM public.stock_process));

COMMIT;
