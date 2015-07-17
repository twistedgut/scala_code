BEGIN;

    update inventory set allocated_quantity = allocated_quantity - 1
    where id in (35299, 568434);

COMMIT;
