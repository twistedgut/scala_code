BEGIN;
    SELECT setval('stock_action_id_seq', (SELECT MAX(id) FROM stock_action));
    INSERT INTO public.stock_action (action) VALUES ('Dead - No RTV');
COMMIT;
