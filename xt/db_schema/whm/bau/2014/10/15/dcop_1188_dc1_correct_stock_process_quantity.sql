BEGIN;

    update log_delivery set quantity = 2 where delivery_id = 2709432 and type_id = 2;
    update stock_process set quantity = 2 where group_id = 4203953;

COMMIT;