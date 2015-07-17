BEGIN;
    SELECT setval('classification_id_seq', (SELECT MAX(id) FROM public.classification)+1);
    SELECT setval('product_type_id_seq', (SELECT MAX(id) FROM public.product_type)+1);
    SELECT setval('sub_type_id_seq', (SELECT MAX(id) FROM public.sub_type)+1);
COMMIT;
