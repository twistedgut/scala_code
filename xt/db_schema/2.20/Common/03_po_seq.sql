BEGIN;
    SELECT setval('purchase_order_id_seq', (SELECT max(id) FROM super_purchase_order));
COMMIT;
